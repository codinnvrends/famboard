import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:famboard/app/services.dart';
import 'package:famboard/data/blob_store.dart';
import 'package:famboard/data/db/connection.dart';
import 'package:famboard/data/db/database.dart';
import 'package:famboard/data/famboard_repository.dart';
import 'package:famboard/data/key_vault.dart';
import 'package:famboard/data/record_store.dart';
import 'package:famboard/data/settings_store.dart';
import 'package:famboard/domain/change.dart';
import 'package:famboard/domain/models.dart';
import 'package:famboard/domain/permissions.dart';
import 'package:famboard/domain/warranty.dart';
import 'package:famboard/services/notifications.dart';
import 'package:famboard/services/receipt/ocr_types.dart';
import 'package:famboard/services/warranty/warranty_parser.dart';
import 'package:famboard/sync/channel.dart';
import 'package:famboard/sync/secure_channel.dart';
import 'package:famboard/sync/sync_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'end_to_end_sync_test.dart' show FakeNetwork, FakeTransport, NoopNotifications;

Appliance _a({
  String id = 'a',
  DateTime? bought,
  int? months,
  DateTime? ends,
  DateTime? extraEnds,
  String? extraProvider,
  String? by,
  DateTime? at,
  bool deleted = false,
}) =>
    Appliance(
      id: id,
      familyId: 'fam',
      name: 'Item $id',
      purchaseDate: bought,
      warrantyMonths: months,
      warrantyEnds: ends,
      extraEnds: extraEnds,
      extraProvider: extraProvider,
      createdBy: by,
      createdAt: at,
      updatedAt: DateTime(2026),
      deleted: deleted,
    );

OcrPage _page(List<String> lines) => OcrPage([
      for (final (i, l) in lines.indexed) OcrFragment(l, 20, 40.0 * i, 20 + l.length * 12.0, 40.0 * i + 24),
    ]);

Uint8List _bytes(int n, int seed) {
  final r = Random(seed);
  return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final today = DateTime(2026, 11, 22);

  group('cover edge cases', () {
    test('no purchase date, or a zero length, means the end is unknown', () {
      expect(_a(months: 12).warranty.ends, isNull);
      expect(_a(bought: DateTime(2026, 1, 1), months: 0).warranty.ends, isNull);
      expect(_a(bought: DateTime(2026, 1, 1)).warranty.state(today), CoverState.unknown);
    });

    test('the 30-day "ending soon" window is inclusive', () {
      expect(_a(ends: today.add(const Duration(days: 30))).warranty.state(today), CoverState.expiringSoon);
      expect(_a(ends: today.add(const Duration(days: 31))).warranty.state(today), CoverState.active);
      expect(_a(ends: today).warranty.daysLeft(today), 0);
    });

    test('an AMC with no maker warranty still counts as cover', () {
      final a = _a(extraEnds: DateTime(2027, 3, 1));
      expect(a.bestIsExtra, isTrue);
      expect(a.bestCover.ends, DateTime(2027, 3, 1));
      expect(a.hasExtra, isTrue);
      expect(_a(extraProvider: 'OneAssist').hasExtra, isTrue, reason: 'provider known, end not yet');
      expect(_a(extraProvider: 'OneAssist').extra, isNull);
    });

    test('covered on the last day, not the day after', () {
      final a = _a(ends: DateTime(2026, 12, 31));
      expect(a.coveredOn(DateTime(2026, 12, 31, 23, 59)), isTrue);
      expect(a.coveredOn(DateTime(2027, 1, 1)), isFalse);
      expect(_a().coveredOn(today), isFalse);
    });

    test('bad synced data reads safely', () {
      final a = Appliance.fromRecord(RecordState(entity: Entities.appliance, id: 'x', familyId: 'fam', fields: {
        'name': '   ',
        'price': 'lots',
        'warrantyMonths': 12.0,
        'purchaseDate': 'not a date',
        'photos': ['p1', 3, '', null, 'p2'],
        'photoKinds': {'p1': 'card', 'p2': 'mystery', 7: 'bill'},
        'extraKind': 'warp',
      }));
      expect(a.name, '?');
      expect(a.price, isNull);
      expect(a.warrantyMonths, 12);
      expect(a.purchaseDate, isNull);
      expect(a.photos, ['p1', 'p2']);
      expect(a.photoKinds, {'p1': PhotoKind.card, 'p2': PhotoKind.other});
      expect(a.extraKind, ExtraCoverKind.extended);
    });

    test('blank text is stored as nothing, and money can be left out', () {
      final f = const ApplianceDraft(name: '  Fan  ', brand: '  ', price: 900, extraCost: 300).toFields(includePrice: false);
      expect(f['name'], 'Fan');
      expect(f['brand'], isNull);
      expect(f.containsKey('price'), isFalse);
      expect(f.containsKey('extraCost'), isFalse);
      expect(f['photoKinds'], isEmpty);
    });
  });

  group('permission edge cases', () {
    final now = DateTime(2026, 11, 22, 12);

    test('the 24-hour window closes exactly at 24 hours', () {
      const p = Perms(Role.member, 'me');
      expect(p.canEditAppliance(_a(by: 'me', at: now.subtract(const Duration(hours: 23, minutes: 59))), now: now), isTrue);
      expect(p.canEditAppliance(_a(by: 'me', at: now.subtract(const Duration(hours: 24))), now: now), isFalse);
    });

    test('no adder or no time recorded: only admins may change it', () {
      const p = Perms(Role.member, 'me');
      expect(p.canEditAppliance(_a(by: 'me'), now: now), isFalse);
      expect(p.canEditAppliance(_a(at: now), now: now), isFalse);
      expect(const Perms(Role.admin, 'x').canEditAppliance(_a(), now: now), isTrue);
    });

    test('a viewer or child never edits, even their own fresh item', () {
      final mine = _a(by: 'me', at: now);
      expect(const Perms(Role.viewer, 'me').canEditAppliance(mine, now: now), isFalse);
      expect(const Perms(Role.child, 'me').canAddAppliance, isFalse);
      expect(const Perms(Role.child, 'me').canAddServiceVisit, isFalse);
    });

    test('service visits follow the same 24-hour rule', () {
      const p = Perms(Role.member, 'me');
      ServiceVisit v(String by, Duration ago) =>
          ServiceVisit(id: 'v', applianceId: 'a', date: now, issue: 'x', createdBy: by, createdAt: now.subtract(ago));
      expect(p.canEditServiceVisit(v('me', const Duration(hours: 2)), now: now), isTrue);
      expect(p.canEditServiceVisit(v('me', const Duration(days: 2)), now: now), isFalse);
      expect(p.canEditServiceVisit(v('other', const Duration(hours: 1)), now: now), isFalse);
      expect(const Perms(Role.admin, 'boss').canEditServiceVisit(v('other', const Duration(days: 9)), now: now), isTrue);
    });

    test('before this phone knows its own role, it is treated as a member', () {
      // permsProvider passes Role.member and no money flag until the member
      // record arrives: members see money by default.
      expect(const Perms(Role.member, '').canSeeMoney, isTrue);
    });

    test('hiding money hides only bills; other entry types stay visible', () {
      final p = Perms.of(const Member(id: 'k', familyId: 'fam', name: 'K', role: Role.child));
      for (final t in EntryType.values) {
        final e = Entry(
          id: t.code, familyId: 'fam', title: t.code, type: t, categoryId: 'other',
          priority: Priority.normal, status: EntryStatus.open, updatedAt: today,
        );
        expect(p.canView(e), t != EntryType.bill, reason: t.code);
      }
    });

    test('list items lose their prices for people without money access', () {
      const i = ListItem(id: 'i', listId: 'l', name: 'Rice', position: 1, quantity: 5, unit: 'kg', rate: 60, amount: 300, checked: true);
      final x = i.withoutPrices();
      expect([x.name, x.quantity, x.unit, x.checked], ['Rice', 5, 'kg', true]);
      expect(x.rate, isNull);
      expect(x.amount, isNull);
    });
  });

  group('reminder edge cases', () {
    final texts = ReminderTexts(
      channelName: 'r', dueToday: (t) => t, dueIn: (t, d) => t, digestTitle: 'd', digestBody: 'd',
      warrantyEndsIn: (n, d) => 'W $n $d', extraEndsIn: (n, d) => 'X $n $d',
    );
    List<PlannedReminder> plan(List<Appliance> a, {ReminderTexts? t}) => const ReminderPlanner()
        .plan(entries: const [], now: DateTime(2026, 11, 22, 10), billLeadDays: 3, texts: t ?? texts, appliances: a);

    test('deleted items, unknown ends and expired covers give no reminders', () {
      expect(plan([_a(ends: DateTime(2026, 12, 30), deleted: true)]), isEmpty);
      expect(plan([_a()]), isEmpty);
      expect(plan([_a(ends: DateTime(2026, 11, 1))]), isEmpty);
    });

    test('reminders beyond the planning horizon wait for a later run', () {
      // 60-day horizon: ends 1 Mar 2027 → 30-day reminder on 30 Jan is out.
      expect(plan([_a(ends: DateTime(2027, 3, 1))]), isEmpty);
      // Ends 18 Feb: the 30-day reminder (19 Jan) is inside, the 7-day one isn't yet.
      expect(plan([_a(ends: DateTime(2027, 2, 18))]).map((r) => r.title), ['W Item a 30']);
    });

    test('older app texts without warranty wording skip warranty reminders', () {
      final old = ReminderTexts(channelName: 'r', dueToday: (t) => t, dueIn: (t, d) => t, digestTitle: 'd', digestBody: 'd');
      expect(plan([_a(ends: DateTime(2026, 12, 10))], t: old), isEmpty);
    });

    test('ids never collide between entries and appliances with the same id', () {
      final e = Entry(
        id: 'same', familyId: 'fam', title: 'Bill', type: EntryType.bill, categoryId: 'bills',
        priority: Priority.normal, status: EntryStatus.open, updatedAt: today, dueAt: DateTime(2026, 12, 15), leadDays: 7,
      );
      final r = const ReminderPlanner().plan(
        entries: [e],
        now: DateTime(2026, 11, 22, 10),
        billLeadDays: 3,
        texts: texts,
        appliances: [_a(id: 'same', ends: DateTime(2026, 12, 20), extraEnds: DateTime(2026, 12, 25))],
      );
      // Bill: due + 7 days before; warranty: 7 days (30 is past); AMC: 30 and 7.
      expect(r.length, 5);
      expect(r.map((x) => x.id).toSet().length, 5);
    });
  });

  group('OCR edge cases', () {
    final parser = WarrantyParser();

    test('a label on one line with its value on the next', () {
      final g = parser.parse([_page(['Model No:', 'WM-8KG-FL', 'Serial Number', 'SN99887766'])]);
      expect(g.model, 'WM-8KG-FL');
      expect(g.serial, 'SN99887766');
    });

    test('short brand names only match as whole capital words', () {
      expect(parser.parse([_page(['Shop at Bengaluru bulging sale'])]).brand, isNull);
      expect(parser.parse([_page(['HP LaserJet printer'])]).brand, 'HP');
      // "Mi" alone is ignored when a better brand is present.
      expect(parser.parse([_page(['Mi', 'Xiaomi Redmi Note', 'Redmi'])]).brand, isNot('Mi'));
    });

    test('warranty lengths in words, months, and nonsense', () {
      expect(parser.parse([_page(['Two years warranty'])]).warrantyMonths, 24);
      expect(parser.parse([_page(['18 months warranty on product'])]).warrantyMonths, 18);
      expect(parser.parse([_page(['Warranty: 5 yrs'])]).warrantyMonths, 60);
      expect(parser.parse([_page(['99 years warranty'])]).warrantyMonths, isNull, reason: 'over 20 years is a misread');
    });

    test('price falls back to the priciest line when there is no total', () {
      final g = parser.parse([_page(['Mixer grinder 750W 1 3499.00', 'Jar extra 1 499.00'])]);
      expect(g.price, 3499);
    });

    test('helpline numbers in the usual groupings', () {
      expect(parser.parse([_page(['Call 1800 102 5678'])]).helpline, '1800-102-5678');
      expect(parser.parse([_page(['Care: 1860-500-1234'])]).helpline, '1860-500-1234');
      expect(parser.parse([_page(['Phone 022 2345 6789'])]).helpline, isNull, reason: 'not toll-free');
    });

    test('dates: two-digit years, full month names, impossible dates', () {
      expect(WarrantyParser.parseDate('1-Jan-24'), DateTime(2024, 1, 1));
      expect(WarrantyParser.parseDate('03 September 2025'), DateTime(2025, 9, 3));
      expect(WarrantyParser.parseDate('29/02/2025'), isNull);
      expect(WarrantyParser.parseDate('00/01/2025'), isNull);
      expect(WarrantyParser.parseDate('01/01/1980'), isNull, reason: 'too old to be a purchase');
    });

    test('a photo with as many bill as card words counts as a bill', () {
      expect(WarrantyParser.classify(_page(['Tax invoice', 'Warranty card'])), PhotoKind.bill);
      expect(WarrantyParser.classify(const OcrPage([])), PhotoKind.other);
    });

    test('nothing found fills nothing', () {
      expect(const WarrantyGuess().fillsFor({}), isEmpty);
      expect(const WarrantyGuess().found, 0);
    });
  });

  group('repository edge cases', () {
    late RecordStore store;
    late FamBoardRepository repo;
    setUp(() async {
      final db = openMemoryDatabase();
      store = await RecordStore.open(db, 'dev');
      repo = FamBoardRepository(store: store, settings: SettingsStore(db), vault: MemoryKeyVault());
    });

    test('adding without money access stores no price', () async {
      await repo.addAppliance(
        familyId: 'fam', memberId: 'kid', draft: const ApplianceDraft(name: 'Fan', price: 2500), includePrice: false,
      );
      final r = (await store.list('fam', Entities.appliance)).single;
      expect(r.fields.containsKey('price'), isFalse);
    });

    test('editing a service visit keeps who added it, and a hidden cost', () async {
      final id = await repo.saveServiceVisit(
        familyId: 'fam', memberId: 'mum', applianceId: 'a', date: DateTime(2026, 5, 1), issue: 'Gas refill', cost: 1800,
      );
      await repo.saveServiceVisit(
        familyId: 'fam', memberId: 'kid', applianceId: 'a', id: id, date: DateTime(2026, 5, 2), issue: 'Gas refill + filter', includeCost: false,
      );
      final v = ServiceVisit.fromRecord((await store.get(Entities.serviceVisit, id))!);
      expect(v.createdBy, 'mum');
      expect(v.issue, 'Gas refill + filter');
      expect(v.cost, 1800);
      await repo.deleteServiceVisit('fam', id);
      expect(await store.list('fam', Entities.serviceVisit), isEmpty);
    });

    test('an entry without an appliance stores no link', () async {
      final id = await repo.addEntry(
        familyId: 'fam', memberId: 'me', draft: const EntryDraft(title: 'Tap leaking', type: EntryType.repair, categoryId: 'repairs'),
      );
      expect((await store.get(Entities.entry, id))!.fields.containsKey('applianceId'), isFalse);
    });

    test('money access can be given back', () async {
      await repo.setMemberSeesMoney('fam', 'm', false);
      await repo.setMemberSeesMoney('fam', 'm', true);
      expect((await store.get(Entities.member, 'm'))!.fields['seesMoney'], isTrue);
    });
  });

  group('photo storage edge cases', () {
    late AppDatabase db;
    late RecordStore store;
    late BlobStore blobs;
    setUp(() async {
      db = openMemoryDatabase();
      store = await RecordStore.open(db, 'dev');
      blobs = BlobStore(db, store);
    });

    test('the same photo twice is stored once, under the same id', () async {
      final b = _bytes(2000, 1);
      final a = await blobs.put('fam', b);
      final c = await blobs.put('fam', b);
      expect(a, c);
      expect((await blobs.all('fam')).length, 1);
    });

    test('photos stay within their family', () async {
      final id = await blobs.put('fam', _bytes(500, 2));
      expect(await blobs.blob('other', id), isNull);
      expect(await blobs.all('other'), isEmpty);
    });

    test('photos of deleted items are no longer wanted', () async {
      await store.write(const RecordWrite(familyId: 'fam', entity: Entities.appliance, id: 'x', fields: {'name': 'TV', 'photos': ['p1']}));
      expect(await blobs.missingBlobs('fam'), ['p1']);
      await store.delete('fam', Entities.appliance, 'x');
      expect(await blobs.missingBlobs('fam'), isEmpty);
    });
  });

  group('photo sync edge cases', () {
    final key = KeyVault.randomKey();

    Future<(RecordStore, BlobStore)> phone(String id) async {
      final db = openMemoryDatabase();
      final s = await RecordStore.open(db, id);
      return (s, BlobStore(db, s));
    }

    SyncSession session(RecordStore s, BlobStore b, String id) => SyncSession(
          store: s,
          blobs: b,
          identity: LocalIdentity(deviceId: id, deviceName: id),
          memberIdFor: (_) async => 'm$id',
          isMemberAllowed: (_, _) async => true,
        );

    Future<(SyncResult, SyncResult)> sync((RecordStore, BlobStore) a, (RecordStore, BlobStore) b) async {
      final pair = MemoryChannelPair(maxMessageBytes: 1024 * 1024);
      final tag = await familyTag(key);
      final r = await Future.wait([
        session(a.$1, a.$2, 'A').initiate(channel: pair.a, familyId: 'fam', familyKey: key),
        session(b.$1, b.$2, 'B').accept(channel: pair.b, lookup: (t) async => t == tag ? ('fam', key) : null),
      ]).timeout(const Duration(seconds: 10));
      return (r[0], r[1]);
    }

    test('a photo neither phone has does not stall the sync', () async {
      final a = await phone('A');
      final b = await phone('B');
      await a.$1.write(const RecordWrite(familyId: 'fam', entity: Entities.appliance, id: 'x', fields: {'name': 'TV', 'photos': ['lost']}));
      final (ra, rb) = await sync(a, b);
      expect(ra.photosReceived + rb.photosReceived, 0);
      expect(await b.$2.missingBlobs('fam'), ['lost']);
    });

    test('an item with no photos syncs with an empty photo exchange', () async {
      final a = await phone('A');
      final b = await phone('B');
      await a.$1.write(const RecordWrite(familyId: 'fam', entity: Entities.appliance, id: 'x', fields: {'name': 'TV'}));
      final (_, rb) = await sync(a, b);
      expect(rb.received, greaterThan(0));
      expect(rb.photosReceived, 0);
    });
  });

  group('backups and upgrades', () {
    Future<AppServices> app() => AppServices.assemble(
          db: openMemoryDatabase(),
          vault: MemoryKeyVault(),
          transports: [FakeTransport(FakeNetwork())],
          notifications: NoopNotifications(),
          defaultDeviceName: 'P',
        );

    test('a backup carries warranty photos to a new phone', () async {
      final a = await app();
      final fam = await a.repo.createFamily(familyName: 'Home', myName: 'Priya');
      final photo = _bytes(5000, 3);
      final id = await a.blobs.put(fam.id, photo);
      await a.repo.addAppliance(familyId: fam.id, memberId: fam.memberId, draft: ApplianceDraft(name: 'AC', photos: [id]));
      final bytes = await a.backup.createBackup(fam.id, 'secret-123');

      final b = await app();
      await b.backup.restoreBackup(bytes, 'secret-123');
      expect((await b.repo.appliances(fam.id)).single.photos, [id]);
      expect(await b.blobs.blob(fam.id, id), photo);
      await a.sync.dispose();
      await b.sync.dispose();
    });

    test('a phone on the old database gets the photo table on upgrade', () async {
      final dir = await Directory.systemTemp.createTemp('famboard');
      final file = File('${dir.path}/old.db');
      // Build a current database, then make it look like version 1.
      final first = AppDatabase(NativeDatabase(file));
      await first.customStatement('SELECT 1');
      await first.customStatement('DROP TABLE blobs');
      await first.customStatement('PRAGMA user_version = 1');
      await first.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      final store = await RecordStore.open(upgraded, 'dev');
      final blobs = BlobStore(upgraded, store);
      final id = await blobs.put('fam', _bytes(100, 4));
      expect(await blobs.has('fam', id), isTrue);
      await upgraded.close();
      await dir.delete(recursive: true);
    });
  });
}
