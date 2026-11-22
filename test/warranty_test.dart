import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:famboard/data/db/connection.dart';
import 'package:famboard/data/famboard_repository.dart';
import 'package:famboard/data/key_vault.dart';
import 'package:famboard/data/record_store.dart';
import 'package:famboard/data/settings_store.dart';
import 'package:famboard/domain/change.dart';
import 'package:famboard/domain/models.dart';
import 'package:famboard/domain/permissions.dart';
import 'package:famboard/domain/warranty.dart';
import 'package:famboard/services/notifications.dart';
import 'package:flutter_test/flutter_test.dart';

Appliance _a({
  DateTime? bought,
  int? months,
  DateTime? ends,
  DateTime? extraEnds,
  String? by,
  DateTime? at,
  String name = 'Fridge',
}) =>
    Appliance(
      id: name,
      familyId: 'fam',
      name: name,
      purchaseDate: bought,
      warrantyMonths: months,
      warrantyEnds: ends,
      extraEnds: extraEnds,
      createdBy: by,
      createdAt: at,
      updatedAt: DateTime(2026),
    );

Member _m(Role role, {bool? money}) => Member(id: 'me', familyId: 'fam', name: 'Me', role: role, seesMoney: money);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('cover dates', () {
    test('months are added on the calendar and the last day is inclusive', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2024, 1, 31), 1), DateTime(2024, 2, 29));
      expect(addMonths(DateTime(2026, 11, 5), 14), DateTime(2028, 1, 5));
      expect(_a(bought: DateTime(2026, 3, 10), months: 12).warranty.ends, DateTime(2027, 3, 9));
    });

    test('an explicit end date wins over the length', () {
      final a = _a(bought: DateTime(2026, 3, 10), months: 12, ends: DateTime(2027, 6, 1));
      expect(a.warranty.ends, DateTime(2027, 6, 1));
    });

    test('state: active, ending soon, expired, unknown', () {
      final today = DateTime(2026, 11, 22);
      expect(_a(ends: DateTime(2027, 6, 1)).warranty.state(today), CoverState.active);
      expect(_a(ends: DateTime(2026, 12, 10)).warranty.state(today), CoverState.expiringSoon);
      expect(_a(ends: DateTime(2026, 11, 22)).warranty.state(today), CoverState.expiringSoon);
      expect(_a(ends: DateTime(2026, 11, 21)).warranty.state(today), CoverState.expired);
      expect(_a().warranty.state(today), CoverState.unknown);
      expect(_a(ends: DateTime(2026, 11, 30)).warranty.daysLeft(today), 8);
    });

    test('the longer of warranty and AMC is what counts', () {
      final a = _a(ends: DateTime(2026, 1, 1), extraEnds: DateTime(2028, 1, 1));
      expect(a.bestIsExtra, isTrue);
      expect(a.bestCover.ends, DateTime(2028, 1, 1));
      expect(a.coveredOn(DateTime(2027, 5, 5)), isTrue);
      expect(a.coveredOn(DateTime(2028, 1, 2)), isFalse);
      expect(_a(ends: DateTime(2029, 1, 1), extraEnds: DateTime(2028, 1, 1)).bestIsExtra, isFalse);
    });

    test('the tab lists soonest-ending first, unknown next, expired last', () {
      final today = DateTime(2026, 11, 22);
      final list = [
        _a(name: 'old', ends: DateTime(2025, 1, 1)),
        _a(name: 'later', ends: DateTime(2028, 1, 1)),
        _a(name: 'none'),
        _a(name: 'soon', ends: DateTime(2026, 12, 1)),
        _a(name: 'next', ends: DateTime(2027, 2, 1)),
      ]..sort((x, y) => compareAppliances(x, y, today));
      expect(list.map((a) => a.name), ['soon', 'next', 'later', 'none', 'old']);
    });
  });

  group('bills and money access', () {
    test('defaults: admins and members yes, children and viewers no', () {
      expect(Perms.of(_m(Role.admin)).canSeeMoney, isTrue);
      expect(Perms.of(_m(Role.member)).canSeeMoney, isTrue);
      expect(Perms.of(_m(Role.child)).canSeeMoney, isFalse);
      expect(Perms.of(_m(Role.viewer)).canSeeMoney, isFalse);
    });

    test('an admin can allow or hide it per person; admins always see it', () {
      expect(Perms.of(_m(Role.member, money: false)).canSeeMoney, isFalse);
      expect(Perms.of(_m(Role.child, money: true)).canSeeMoney, isTrue);
      expect(Perms.of(_m(Role.admin, money: false)).canSeeMoney, isTrue);
      expect(_m(Role.member, money: false).canSeeMoney, isFalse);
    });

    test('bill entries are hidden, other entries are not', () {
      Entry e(EntryType t) => Entry(
            id: t.code, familyId: 'fam', title: t.code, type: t, categoryId: 'other',
            priority: Priority.normal, status: EntryStatus.open, updatedAt: DateTime(2026),
          );
      final p = Perms.of(_m(Role.member, money: false));
      expect(p.canView(e(EntryType.bill)), isFalse);
      expect(p.canView(e(EntryType.repair)), isTrue);
      expect(Perms.of(_m(Role.member)).canView(e(EntryType.bill)), isTrue);
    });
  });

  group('warranty permissions', () {
    final now = DateTime(2026, 11, 22, 12);
    final mine = _a(by: 'me', at: now.subtract(const Duration(hours: 3)));
    final mineOld = _a(by: 'me', at: now.subtract(const Duration(hours: 25)));
    final theirs = _a(by: 'other', at: now.subtract(const Duration(hours: 1)));

    test('admins and members add; children and viewers only look', () {
      expect(const Perms(Role.admin, 'me').canAddAppliance, isTrue);
      expect(const Perms(Role.member, 'me').canAddAppliance, isTrue);
      expect(const Perms(Role.child, 'me').canAddAppliance, isFalse);
      expect(const Perms(Role.viewer, 'me').canAddAppliance, isFalse);
    });

    test('the adder may fix it for 24 hours, admins always', () {
      const member = Perms(Role.member, 'me');
      expect(member.canEditAppliance(mine, now: now), isTrue);
      expect(member.canDeleteAppliance(mine, now: now), isTrue);
      expect(member.ownEditUntil(mine, now: now), mine.createdAt!.add(const Duration(hours: 24)));
      expect(member.canEditAppliance(mineOld, now: now), isFalse);
      expect(member.canEditAppliance(theirs, now: now), isFalse);
      const admin = Perms(Role.admin, 'boss');
      expect(admin.canEditAppliance(mineOld, now: now), isTrue);
      expect(admin.canDeleteAppliance(theirs, now: now), isTrue);
      expect(admin.ownEditUntil(theirs, now: now), isNull);
    });
  });

  group('reminders', () {
    final texts = ReminderTexts(
      channelName: 'r',
      dueToday: (t) => 'today $t',
      dueIn: (t, d) => '$t in $d',
      digestTitle: 'd',
      digestBody: 'd',
      warrantyEndsIn: (n, d) => 'W $n $d',
      extraEndsIn: (n, d) => 'X $n $d',
    );

    test('30 and 7 days before the warranty and the AMC end', () {
      final now = DateTime(2026, 11, 22, 10);
      final a = Appliance(
        id: 'ac',
        familyId: 'fam',
        name: 'AC',
        warrantyEnds: DateTime(2027, 1, 10),
        extraEnds: DateTime(2026, 12, 20),
        updatedAt: now,
      );
      final plan = const ReminderPlanner().plan(entries: const [], now: now, billLeadDays: 3, texts: texts, appliances: [a]);
      expect(plan.map((r) => (r.title, r.at)), [
        ('X AC 7', DateTime(2026, 12, 13, 9)),
        ('W AC 30', DateTime(2026, 12, 11, 9)),
        ('W AC 7', DateTime(2027, 1, 3, 9)),
      ]..sort((x, y) => x.$2.compareTo(y.$2)));
      // The AMC's 30-day reminder (20 Nov) is already past.
      expect(plan.map((r) => r.id).toSet().length, plan.length);
    });
  });

  group('repository', () {
    late RecordStore store;
    late FamBoardRepository repo;

    setUp(() async {
      final db = openMemoryDatabase();
      store = await RecordStore.open(db, 'dev');
      repo = FamBoardRepository(
        store: store,
        settings: SettingsStore(db),
        vault: MemoryKeyVault(),
        now: () => DateTime(2026, 11, 22, 10),
      );
    });

    test('adding stamps who and when; editing writes only what changed', () async {
      final id = await repo.addAppliance(
        familyId: 'fam',
        memberId: 'me',
        draft: ApplianceDraft(name: 'TV', brand: 'Sony', purchaseDate: DateTime(2026, 5, 1), warrantyMonths: 24, price: 55000),
      );
      final a = (await repo.appliances('fam')).single;
      expect(a.id, id);
      expect(a.createdBy, 'me');
      expect(a.createdAt, DateTime(2026, 11, 22, 10));
      expect(a.warranty.ends, DateTime(2028, 4, 30));

      final before = (await store.allChanges('fam')).length;
      await repo.updateAppliance(
        before: a,
        draft: ApplianceDraft(name: 'TV', brand: 'Sony', purchaseDate: DateTime(2026, 5, 1), warrantyMonths: 36, price: 55000),
        memberId: 'me',
      );
      final fields = (await store.allChanges('fam')).skip(before).map((c) => c.field).toSet();
      expect(fields, {'warrantyMonths', 'updatedBy'});
    });

    test('someone who cannot see money never overwrites the price', () async {
      await repo.addAppliance(
        familyId: 'fam', memberId: 'me', draft: const ApplianceDraft(name: 'Mixer', price: 3000),
      );
      final a = (await repo.appliances('fam')).single;
      await repo.updateAppliance(
        before: a,
        draft: const ApplianceDraft(name: 'Mixer grinder'),
        memberId: 'kid',
        includePrice: false,
      );
      final after = (await repo.appliances('fam')).single;
      expect(after.name, 'Mixer grinder');
      expect(after.price, 3000);
    });

    test('deleting an appliance deletes its service history', () async {
      final id = await repo.addAppliance(familyId: 'fam', memberId: 'me', draft: const ApplianceDraft(name: 'Geyser'));
      await repo.saveServiceVisit(familyId: 'fam', memberId: 'me', applianceId: id, date: DateTime(2026, 6, 1), issue: 'Element changed');
      await repo.saveServiceVisit(familyId: 'fam', memberId: 'me', applianceId: 'other', date: DateTime(2026, 6, 1), issue: 'Not this one');
      await repo.deleteAppliance((await repo.appliances('fam')).single);
      expect(await repo.appliances('fam'), isEmpty);
      final visits = await store.list('fam', Entities.serviceVisit);
      expect(visits.map((r) => r.fields['issue']), ['Not this one']);
    });

    test('a repair can point at an appliance', () async {
      final id = await repo.addEntry(
        familyId: 'fam',
        memberId: 'me',
        draft: const EntryDraft(title: 'AC not cooling', type: EntryType.repair, categoryId: 'repairs', applianceId: 'ac1'),
      );
      final e = Entry.fromRecord((await store.get(Entities.entry, id))!);
      expect(e.applianceId, 'ac1');
    });

    test('an admin hides money from a member', () async {
      await repo.setMemberSeesMoney('fam', 'm1', false);
      final rec = RecordState(entity: Entities.member, id: 'm1', familyId: 'fam', fields: {
        ...?(await store.get(Entities.member, 'm1'))?.fields,
        'role': 'member',
      });
      expect(Member.fromRecord(rec).canSeeMoney, isFalse);
    });
  });
}
