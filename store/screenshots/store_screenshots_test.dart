// Renders the real app with a demo family for the Play Store listing.
// Run: flutter test store/screenshots --update-goldens
// Output: store/screenshots/raw/<lang>_<n>.png
import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:famboard/app/app.dart';
import 'package:famboard/app/providers.dart';
import 'package:famboard/app/services.dart';
import 'package:famboard/data/db/connection.dart';
import 'package:famboard/data/famboard_repository.dart';
import 'package:famboard/data/key_vault.dart';
import 'package:famboard/data/settings_store.dart';
import 'package:famboard/domain/models.dart';
import 'package:famboard/services/receipt/receipt_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../test/end_to_end_sync_test.dart' show FakeNetwork, FakeTransport, NoopNotifications, eventually;

const _sdkFonts = '/home/claude/flutter-sdk/bin/cache/artifacts/material_fonts';

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await loader.load();
}

Future<AppServices> _phone(FakeNetwork net, String name) async {
  final s = await AppServices.assemble(
    db: openMemoryDatabase(),
    vault: MemoryKeyVault(),
    transports: [FakeTransport(net)],
    notifications: NoopNotifications(),
    defaultDeviceName: name,
  );
  await s.settings.set('permissionsAsked', 'true');
  return s;
}

Future<(AppServices, String, String, String, List<AppServices>)> _demo(bool hindi) async {
  final net = FakeNetwork();
  final mum = await _phone(net, 'Priya’s phone');
  final fam = await mum.repo.createFamily(familyName: hindi ? 'शर्मा परिवार' : 'Sharma family', myName: hindi ? 'प्रिया' : 'Priya');
  final others = <AppServices>[];
  final ids = <String, String>{};
  for (final (name, hi) in [('Raj', 'राज'), ('Aarav', 'आरव'), ('Dadi', 'दादी')]) {
    final p = await _phone(net, '$name’s phone');
    final local = await p.repo.joinFamily(
      await mum.repo.createInvite(familyId: fam.id, familyName: 'Sharma family', invitedBy: fam.memberId, role: Role.member),
      myName: hindi ? hi : name,
    );
    ids[name] = local.memberId;
    others.add(p);
  }
  final raj = others[0], aarav = others[1], dadi = others[2];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 19);

  Future<String> add(AppServices who, String memberId, EntryDraft d) =>
      who.repo.addEntry(familyId: fam.id, memberId: memberId, draft: d);

  String t(String en, String hi) => hindi ? hi : en;

  // Things to buy.
  await add(dadi, ids['Dadi']!, EntryDraft(title: t('Milk', 'दूध'), type: EntryType.outOfStock, categoryId: 'groceries.dairy', quantity: 2, unit: 'L', priority: Priority.high));
  await add(mum, fam.memberId, EntryDraft(title: t('Atta', 'आटा'), type: EntryType.needToBuy, categoryId: 'groceries.staples', quantity: 10, unit: 'kg'));
  await add(aarav, ids['Aarav']!, EntryDraft(title: t('Notebooks for school', 'स्कूल की कॉपियाँ'), type: EntryType.needToBuy, categoryId: 'kids.stationery', quantity: 6));
  await add(raj, ids['Raj']!, EntryDraft(title: t('Toothpaste', 'टूथपेस्ट'), type: EntryType.outOfStock, categoryId: 'household.toiletries'));
  await add(dadi, ids['Dadi']!, EntryDraft(title: t('Tea leaves', 'चाय पत्ती'), type: EntryType.needToBuy, categoryId: 'groceries.beverages', quantity: 500, unit: 'g'));
  await add(mum, fam.memberId, EntryDraft(title: t('Onions', 'प्याज़'), type: EntryType.needToBuy, categoryId: 'groceries.produce', quantity: 2, unit: 'kg'));
  // Bills.
  await add(raj, ids['Raj']!, EntryDraft(title: t('Electricity bill', 'बिजली का बिल'), type: EntryType.bill, categoryId: 'bills.electricity', amount: 2340, dueAt: today.add(const Duration(days: 2)), rrule: 'FREQ=MONTHLY;BYMONTHDAY=${today.add(const Duration(days: 2)).day}', leadDays: 3));
  await add(mum, fam.memberId, EntryDraft(title: t('Broadband', 'ब्रॉडबैंड'), type: EntryType.bill, categoryId: 'bills.internet', amount: 799, dueAt: today.add(const Duration(days: 6)), rrule: 'FREQ=MONTHLY;BYMONTHDAY=${today.add(const Duration(days: 6)).day}'));
  await add(raj, ids['Raj']!, EntryDraft(title: t('Society maintenance', 'सोसाइटी मेंटेनेंस'), type: EntryType.bill, categoryId: 'bills.rent', amount: 3500, dueAt: today.subtract(const Duration(days: 1)), rrule: 'FREQ=MONTHLY;BYMONTHDAY=${today.subtract(const Duration(days: 1)).day}'));
  await add(mum, fam.memberId, EntryDraft(title: t('Car insurance', 'कार बीमा'), type: EntryType.bill, categoryId: 'bills.insurance', amount: 14200, dueAt: today.add(const Duration(days: 24)), rrule: 'FREQ=YEARLY'));
  final water = await add(mum, fam.memberId, EntryDraft(title: t('Water bill', 'पानी का बिल'), type: EntryType.bill, categoryId: 'bills.water', amount: 450, dueAt: today));
  final waterEntry = (await mum.repo.entries(fam.id)).firstWhere((e) => e.id == water);
  await mum.repo.setStatus(entry: waterEntry, memberId: fam.memberId, status: EntryStatus.done);
  // Repairs and upgrades.
  final tap = await add(dadi, ids['Dadi']!, EntryDraft(title: t('Bathroom tap leaking', 'बाथरूम का नल टपक रहा है'), type: EntryType.repair, categoryId: 'repairs.plumbing', priority: Priority.high, assigneeId: ids['Raj']));
  await add(aarav, ids['Aarav']!, EntryDraft(title: t('New study lamp', 'पढ़ाई के लिए नया लैंप'), type: EntryType.upgrade, categoryId: 'upgrades.electronics', proposed: true, amount: 1200));
  await add(mum, fam.memberId, EntryDraft(title: t('Water purifier service', 'वॉटर प्यूरीफायर सर्विस'), type: EntryType.task, categoryId: 'repairs.appliances', dueAt: today.add(const Duration(days: 1)), rrule: 'FREQ=MONTHLY;INTERVAL=3'));

  // A scanned bill kept as a list.
  // What a scanned supermarket bill looks like on the review screen.
  final cat = mum.categorizer;
  final bill = ParsedBill(
    store: 'DMart',
    date: today.subtract(const Duration(days: 1)),
    printedTotal: 1937,
    items: [
      for (final (name, q, unit, rate, amount, low) in [
        ('Aashirvaad Atta 10 kg', 1.0, null, 455.0, 455.0, false),
        ('Toor Dal', 2.0, 'kg', 165.0, 330.0, false),
        ('Tata Salt 1 kg', 2.0, null, 28.0, 56.0, false),
        ('Fortune Sunflower Oil 1 L', 1.0, null, 155.0, 155.0, false),
        ('Amul Butter 500 g', 1.0, null, 285.0, 285.0, false),
        ('Red Label Tea 500 g', 1.0, null, 260.0, 260.0, false),
        ('Onion', 1.85, 'kg', 40.0, 74.0, false),
        ('Surf Excel Matic 1 kg', 1.0, null, 210.0, 210.0, true),
        ('Maggi Noodles 280 g', 2.0, null, 56.0, 112.0, false),
      ])
        BillItem(name: name, categoryId: cat.categorize(name).categoryId, quantity: q, unit: unit, rate: rate, amount: amount, lowConfidence: low),
    ],
  );
  final listId = await mum.repo.createList(
    familyId: fam.id,
    memberId: fam.memberId,
    name: t('Monthly groceries', 'महीने का किराना'),
    kind: ListKind.grocery,
    items: [
      for (final (i, x) in [
        ('Aashirvaad Atta', 'आशीर्वाद आटा', 10.0, 'kg', 455.0),
        ('Tata Salt', 'टाटा नमक', 2.0, null, 56.0),
        ('Toor Dal', 'तूर दाल', 2.0, 'kg', 330.0),
        ('Fortune Sunflower Oil', 'फ़ॉर्च्यून सनफ़्लावर तेल', 1.0, 'L', 155.0),
        ('Basmati Rice', 'बासमती चावल', 5.0, 'kg', 640.0),
        ('Amul Butter 500 g', 'अमूल बटर 500 g', 1.0, null, 285.0),
        ('Red Label Tea 500 g', 'रेड लेबल चाय 500 g', 1.0, null, 260.0),
        ('Surf Excel 1 kg', 'सर्फ़ एक्सेल 1 kg', 1.0, null, 140.0),
        ('Haldi Powder 200 g', 'हल्दी पाउडर 200 g', 1.0, null, 78.0),
      ].indexed)
        ListItem(id: '', listId: '', name: t(x.$1, x.$2), quantity: x.$3, unit: x.$4, amount: x.$5, position: i.toDouble(), checked: i < 3),
    ],
    storeName: 'DMart',
    billDate: today.subtract(const Duration(days: 28)),
    billTotal: 2399,
    fromBill: true,
  );
  await mum.repo.createList(
    familyId: fam.id, memberId: fam.memberId, name: t('Diwali shopping', 'दिवाली की ख़रीदारी'), kind: ListKind.general,
    items: [for (final n in ['Diyas', 'Rangoli colours', 'Sweets box', 'Lights']) ListItem(id: '', listId: '', name: n, position: 0)],
  );

  await mum.sync.start();
  for (final o in others) {
    await o.sync.start();
  }
  for (var i = 0; i < 2; i++) {
    for (final p in [mum, ...others]) {
      await p.sync.syncAll(force: true);
    }
  }
  await eventually(() async => (await mum.repo.entries(fam.id)).length >= 13 && (await mum.repo.members(fam.id)).length == 4);
  // Raj has started on the tap.
  final tapEntry = (await raj.repo.entries(fam.id)).firstWhere((e) => e.id == tap);
  await raj.repo.setStatus(entry: tapEntry, memberId: ids['Raj']!, status: EntryStatus.inProgress);
  await raj.sync.syncAll(force: true);
  await eventually(() async => (await mum.repo.entries(fam.id)).any((e) => e.id == tap && e.status == EntryStatus.inProgress));
  if (hindi) await mum.settings.set(SettingsStore.kLocale, 'hi');
  // Keep the scanned bill for the review screen.
  _bill = bill;
  return (mum, fam.id, fam.memberId, listId, others);
}

Object? _bill;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  for (final lang in ['en', 'hi']) {
    testWidgets('store screenshots $lang', (tester) async {
      debugDisableShadows = false;
      await tester.runAsync(() async {
        await initializeDateFormatting();
        final roboto = ['Regular', 'Medium', 'Bold', 'Light'].map((w) => '$_sdkFonts/Roboto-$w.ttf').toList();
        await _font('Roboto', lang == 'hi'
            ? ['assets/fonts/NotoSansDevanagari-Regular.ttf', 'assets/fonts/NotoSansDevanagari-Bold.ttf']
            : roboto);
        await _font('MaterialIcons', ['$_sdkFonts/MaterialIcons-Regular.otf']);
      });
      // Pixel 7-ish: 1080 x 2400 at 2.625.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);

      final (mum, familyId, _, listId, others) = (await tester.runAsync(() => _demo(lang == 'hi')))!;
      await tester.pumpWidget(RepaintBoundary(
        child: ProviderScope(overrides: [servicesProvider.overrideWithValue(mum)], child: const FamBoardApp()),
      ));

      Future<void> settle([int n = 30]) async {
        for (var i = 0; i < n; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
          await tester.pump(const Duration(milliseconds: 60));
        }
      }

      var n = 0;
      Future<void> shot(String name) async {
        for (final m in tester.stateList<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))) {
          m.removeCurrentSnackBar(reason: SnackBarClosedReason.remove);
        }
        await settle(12);
        n++;
        await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('raw/${lang}_${n}_$name.png'));
      }

      GoRouter router() => GoRouter.of(tester.element(find.byType(Scaffold).first));

      await settle(40);
      await shot('today');

      unawaited(router().push('/shopping'));
      await settle();
      await shot('shopping');
      router().pop();
      await settle();

      router().go('/bills');
      await settle();
      await shot('bills');

      router().go('/today');
      await settle();
      // Quick add with live categorisation.
      await tester.tap(find.byType(FloatingActionButton).first);
      await settle();
      await tester.enterText(find.byType(TextField).first, lang == 'hi' ? 'गैस सिलेंडर ख़त्म' : 'Gas cylinder empty');
      await settle(20);
      await shot('quick_add');
      await tester.tapAt(const Offset(200, 60));
      await settle();
      final nav = Navigator.of(tester.element(find.byType(Scaffold).first), rootNavigator: true);
      if (nav.canPop()) nav.pop();
      await settle();

      unawaited(router().push('/bill-review', extra: _bill));
      await settle();
      await shot('bill_review');
      router().pop();
      await settle();

      unawaited(router().push('/saved-lists/$listId'));
      await settle();
      await shot('saved_list');
      router().pop();
      await settle();

      router().go('/family');
      await settle();
      await shot('family');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      debugDisableShadows = true;
      await tester.runAsync(() async {
        for (final s in [mum, ...others]) {
          await s.sync.dispose().timeout(const Duration(seconds: 2), onTimeout: () {});
        }
      });
    });
  }
}
