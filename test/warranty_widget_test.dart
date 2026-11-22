import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:famboard/app/app.dart';
import 'package:famboard/app/providers.dart';
import 'package:famboard/app/services.dart';
import 'package:famboard/data/db/connection.dart';
import 'package:famboard/data/famboard_repository.dart';
import 'package:famboard/data/key_vault.dart';
import 'package:famboard/domain/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'end_to_end_sync_test.dart' show FakeNetwork, FakeTransport, NoopNotifications;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  setUpAll(initializeDateFormatting);

  Future<AppServices> services() async {
    final s = await AppServices.assemble(
      db: openMemoryDatabase(),
      vault: MemoryKeyVault(),
      transports: [FakeTransport(FakeNetwork())],
      notifications: NoopNotifications(),
      defaultDeviceName: 'Test phone',
    );
    await s.settings.set('permissionsAsked', 'true');
    return s;
  }

  Future<void> settle(WidgetTester tester, [int rounds = 25]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<(AppServices, String)> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    final s = (await tester.runAsync(services))!;
    final fam = (await tester.runAsync(() => s.repo.createFamily(familyName: 'Home', myName: 'Priya')))!;
    await tester.runAsync(s.families.refresh);
    await tester.pumpWidget(ProviderScope(
      overrides: [servicesProvider.overrideWithValue(s)],
      child: const FamBoardApp(),
    ));
    await settle(tester);
    return (s, fam.id);
  }

  Future<void> finish(WidgetTester tester, AppServices s) async {
    await tester.runAsync(() => s.sync.dispose());
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 5));
  }

  Finder navItem(String label) =>
      find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

  testWidgets('add a warranty by hand and find it on the Warranties tab', (tester) async {
    final (s, familyId) = await start(tester);

    await tester.tap(navItem('Warranties'));
    await settle(tester);
    expect(find.text('Keep every warranty in one place'), findsOneWidget);

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Add warranty'));
    await settle(tester);
    await tester.tap(find.text('Type it in'));
    await settle(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'What is it?'), 'Bedroom AC');
    await tester.enterText(find.widgetWithText(TextFormField, 'Brand'), 'Voltas');
    await tester.tap(find.widgetWithText(ChoiceChip, '2 years'));
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await settle(tester);

    final saved = (await tester.runAsync(() => s.repo.appliances(familyId)))!.single;
    expect(saved.name, 'Bedroom AC');
    expect(saved.brand, 'Voltas');
    expect(saved.warrantyMonths, 24);
    expect(saved.createdBy, isNotNull);

    // Detail page: no purchase date yet, so the end isn't known.
    expect(find.text('Warranty end not known'), findsWidgets);
    expect(find.byTooltip('Edit'), findsOneWidget);

    await tester.pageBack();
    await settle(tester);
    expect(find.text('Bedroom AC'), findsOneWidget);
    await finish(tester, s);
  });

  testWidgets('someone without money access has no Bills tab and no bills', (tester) async {
    final (s, familyId) = await start(tester);
    final me = (await tester.runAsync(() => s.settings.families()))!.single.memberId;
    await tester.runAsync(() => s.repo.addEntry(
          familyId: familyId,
          memberId: me,
          draft: const EntryDraft(title: 'Electricity bill', type: EntryType.bill, categoryId: 'bills', amount: 950),
        ));
    await tester.runAsync(() => s.repo.addEntry(
          familyId: familyId,
          memberId: me,
          draft: const EntryDraft(title: 'Buy milk', type: EntryType.needToBuy, categoryId: 'groceries'),
        ));
    await tester.tap(navItem('Lists'));
    await settle(tester);
    expect(navItem('Bills'), findsOneWidget);
    expect(find.text('Electricity bill'), findsOneWidget);

    // An admin made this person a member without money access.
    await tester.runAsync(() => s.repo.setMemberRole(familyId, me, Role.member));
    await tester.runAsync(() => s.repo.setMemberSeesMoney(familyId, me, false));
    await settle(tester);

    expect(navItem('Bills'), findsNothing);
    expect(navItem('Warranties'), findsOneWidget);
    expect(find.text('Electricity bill'), findsNothing);
    expect(find.text('Buy milk'), findsOneWidget);
    await finish(tester, s);
  });
}
