import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:famboard/app/app.dart';
import 'package:famboard/app/providers.dart';
import 'package:famboard/app/services.dart';
import 'package:famboard/data/db/connection.dart';
import 'package:famboard/data/key_vault.dart';
import 'package:famboard/data/settings_store.dart';
import 'package:famboard/domain/models.dart';
import 'package:famboard/services/receipt/ocr_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'end_to_end_sync_test.dart' show FakeNetwork, FakeTransport, NoopNotifications;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUpAll(() async {
    await initializeDateFormatting();
  });

  Future<AppServices> services() async {
    final s = await AppServices.assemble(
      db: openMemoryDatabase(),
      vault: MemoryKeyVault(),
      transports: [FakeTransport(FakeNetwork())],
      notifications: NoopNotifications(),
      defaultDeviceName: 'Test phone',
    );
    // Skip the first-run permission prompts in tests.
    await s.settings.set('permissionsAsked', 'true');
    return s;
  }

  /// Alternates real time (database work) and frames until [done] holds.
  Future<void> pumpUntil(WidgetTester tester, bool Function() done, {int max = 150}) async {
    for (var i = 0; i < max && !done(); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(done(), isTrue, reason: 'condition not reached');
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 25; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('create a family, quick-add with auto category, complete it', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);

    final s = await tester.runAsync(services);
    await tester.pumpWidget(ProviderScope(
      overrides: [servicesProvider.overrideWithValue(s!)],
      child: const FamBoardApp(),
    ));
    await settle(tester);

    // Onboarding.
    expect(find.text('Create a family'), findsOneWidget);
    await tester.tap(find.text('Create a family'));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Family name'), 'Sharma home');
    await tester.enterText(find.widgetWithText(TextField, 'Your name'), 'Priya');
    await tester.pump();
    await tester.tap(find.text('Create family'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await settle(tester);

    // Home: empty Today.
    await pumpUntil(tester, () => find.text('All clear for today').evaluate().isNotEmpty);
    expect(find.text('Sharma home'), findsWidgets);
    expect(find.text('All clear for today'), findsOneWidget);

    // Quick add: typing categorizes live.
    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'bathroom tap leaking');
    await settle(tester);
    await pumpUntil(tester, () => find.text('Plumbing').evaluate().isNotEmpty);
    expect(find.text('Plumbing'), findsOneWidget);
    final repairChip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Repair'));
    expect(repairChip.selected, isTrue);

    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await settle(tester);

    final session = (await tester.runAsync(() => s.settings.families()))!.single;
    final entries = (await tester.runAsync(() => s.repo.entries(session.id)))!;
    expect(entries.single.title, 'bathroom tap leaking');
    expect(entries.single.type, EntryType.repair);
    expect(entries.single.categoryId, 'repairs.plumbing');

    // Lists tab shows it; tick it done.
    await tester.tap(find.text('Lists'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await settle(tester);
    expect(find.text('bathroom tap leaking'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.check_circle_outline).first);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await settle(tester);
    final after = (await tester.runAsync(() => s.repo.entries(session.id)))!;
    expect(after.single.status, EntryStatus.done);

    // Switch to Hindi: the navigation is translated.
    await tester.runAsync(() => s.settings.set(SettingsStore.kLocale, 'hi'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await settle(tester);
    expect(find.text('सूचियाँ'), findsWidgets);

    await tester.runAsync(() => s.sync.dispose());
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('review a scanned bill, fix a line, save it as a list', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);

    final s = await tester.runAsync(services);
    final fam = (await tester.runAsync(() => s!.repo.createFamily(familyName: 'Home', myName: 'Priya')))!;
    final page = OcrPage.fromJson(
        jsonDecode(File('test/fixtures/bills/varnamm_tailor.json').readAsStringSync()) as Map<String, Object?>);
    final bill = s!.billScanner.parser.parse(page);

    await tester.pumpWidget(ProviderScope(
      overrides: [servicesProvider.overrideWithValue(s)],
      child: const FamBoardApp(),
    ));
    await settle(tester);
    await pumpUntil(tester, () => find.byIcon(Icons.document_scanner_outlined).evaluate().isNotEmpty);

    unawaited(GoRouter.of(tester.element(find.byType(NavigationBar))).push('/bill-review', extra: bill));
    await settle(tester);
    expect(find.text('Check items'), findsOneWidget);
    expect(find.textContaining('Adds up to the bill total'), findsOneWidget);

    // Fix the first line's name.
    await tester.tap(find.text(bill.items.first.name));
    await settle(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Item'), 'Blouse stitching');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await settle(tester);
    expect(find.text('Blouse stitching'), findsOneWidget);

    await tester.tap(find.text('Save list'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await settle(tester);

    final lists = (await tester.runAsync(() => s.repo.watchLists(fam.id).first))!;
    expect(lists.single.fromBill, isTrue);
    final items = (await tester.runAsync(() => s.repo.listItems(fam.id, lists.single.id)))!;
    expect(items.length, bill.items.length);
    expect(items.first.name, 'Blouse stitching');
    // Now on the saved list itself.
    await pumpUntil(tester, () => find.byType(CheckboxListTile).evaluate().length == items.length);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
    await tester.runAsync(() => s.sync.dispose().timeout(const Duration(seconds: 2), onTimeout: () {}));
  });
}
