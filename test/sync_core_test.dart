import 'dart:math';

import 'package:famboard/core/hlc.dart';
import 'package:famboard/data/db/connection.dart';
import 'package:famboard/data/record_store.dart';
import 'package:famboard/domain/change.dart';
import 'package:famboard/domain/merge.dart';
import 'package:famboard/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

Change _c(String field, Object? value, Hlc hlc, {String record = 'e1'}) =>
    Change(
      id: '$field-$hlc',
      familyId: 'f1',
      entity: Entities.entry,
      recordId: record,
      field: field,
      value: value,
      hlc: hlc,
    );

Map<String, Object?> _status(String s, [int e = 0]) =>
    StatusValue(s, e).toJson();

void main() {
  group('Hlc', () {
    test('string form sorts like the clock', () {
      final a = const Hlc(1000, 2, 'a');
      final b = const Hlc(1000, 10, 'a');
      final c = const Hlc(20000, 0, 'a');
      expect(a.toString().compareTo(b.toString()), lessThan(0));
      expect(b.toString().compareTo(c.toString()), lessThan(0));
      expect(Hlc.parse(b.toString()), b);
    });

    test('tick is monotonic even when the wall clock goes backwards', () {
      var now = 5000;
      final clock = HlcClock('n', now: () => now);
      final t1 = clock.tick();
      now = 4000;
      final t2 = clock.tick();
      expect(t2 > t1, isTrue);
    });

    test('receive moves past a remote clock', () {
      final clock = HlcClock('a', now: () => 1000);
      clock.receive(const Hlc(9000, 3, 'b'));
      expect(clock.tick() > const Hlc(9000, 3, 'b'), isTrue);
    });

    test('ignores remote clocks more than a day ahead', () {
      final clock = HlcClock('a', now: () => 1000);
      clock.receive(Hlc(1000 + Hlc.maxDriftMillis + 5, 0, 'b'));
      expect(clock.tick().millis, 1000);
    });
  });

  group('MergeRules', () {
    const rules = MergeRules();
    RecordState fresh() =>
        RecordState(entity: Entities.entry, id: 'e1', familyId: 'f1');

    test('last writer wins for ordinary fields', () {
      final s = fresh();
      rules.apply(s, _c('title', 'milk', const Hlc(2, 0, 'a')));
      rules.apply(s, _c('title', 'old', const Hlc(1, 0, 'b')));
      expect(s.fields['title'], 'milk');
      rules.apply(s, _c('title', 'curd', const Hlc(3, 0, 'b')));
      expect(s.fields['title'], 'curd');
    });

    test('done beats a later "in progress" in the same epoch', () {
      final s = fresh();
      rules.apply(s, _c('status', _status('done'), const Hlc(5, 0, 'a')));
      rules.apply(s, _c('status', _status('in_progress'), const Hlc(9, 0, 'b')));
      expect(StatusValue.fromJson(s.fields['status']).status, 'done');
    });

    test('an explicit reopen (new epoch) beats done', () {
      final s = fresh();
      rules.apply(s, _c('status', _status('done'), const Hlc(5, 0, 'a')));
      rules.apply(s, _c('status', _status('open', 1), const Hlc(6, 0, 'b')));
      expect(StatusValue.fromJson(s.fields['status']).status, 'open');
    });

    test('edit after delete restores; delete after edit stays deleted', () {
      final s = fresh();
      rules.apply(s, _c('title', 'tap', const Hlc(1, 0, 'a')));
      rules.apply(s, _c('_deleted', true, const Hlc(2, 0, 'a')));
      expect(s.isDeleted, isTrue);
      rules.apply(s, _c('note', 'still needed', const Hlc(3, 0, 'b')));
      expect(s.isDeleted, isFalse);

      final t = fresh();
      rules.apply(t, _c('title', 'tap', const Hlc(1, 0, 'a')));
      rules.apply(t, _c('note', 'x', const Hlc(2, 0, 'b')));
      rules.apply(t, _c('_deleted', true, const Hlc(3, 0, 'a')));
      expect(t.isDeleted, isTrue);
    });

    test('any delivery order converges to the same state', () {
      final rnd = Random(42);
      final statuses = ['open', 'in_progress', 'done', 'cancelled'];
      for (var round = 0; round < 200; round++) {
        final changes = <Change>[];
        for (var i = 0; i < 12; i++) {
          final node = 'n${rnd.nextInt(3)}';
          final hlc = Hlc(rnd.nextInt(50), rnd.nextInt(3), node);
          final kind = rnd.nextInt(4);
          changes.add(switch (kind) {
            0 => _c('title', 'v$i', hlc),
            1 => _c('status',
                _status(statuses[rnd.nextInt(4)], rnd.nextInt(2)), hlc),
            2 => _c('_deleted', rnd.nextBool(), hlc),
            _ => _c('amount', rnd.nextInt(1000), hlc),
          });
        }
        final reference = fresh();
        for (final c in changes) {
          rules.apply(reference, c);
        }
        for (var shuffle = 0; shuffle < 5; shuffle++) {
          final s = fresh();
          for (final c in (changes.toList()..shuffle(rnd))) {
            rules.apply(s, c);
          }
          expect(s.fields, reference.fields, reason: 'round $round');
          expect(s.isDeleted, reference.isDeleted);
        }
      }
    });
  });

  group('RecordStore', () {
    late RecordStore a;
    late RecordStore b;

    setUp(() async {
      a = await RecordStore.open(openMemoryDatabase(), 'deviceA');
      b = await RecordStore.open(openMemoryDatabase(), 'deviceB');
    });

    tearDown(() async {
      await a.db.close();
      await b.db.close();
    });

    Future<void> syncPair(RecordStore x, RecordStore y) async {
      final toY = await x.changesSince('f1', await y.versionVector('f1'));
      final toX = await y.changesSince('f1', await x.versionVector('f1'));
      await y.applyRemote(toY);
      await x.applyRemote(toX);
    }

    test('writes records and reads them back', () async {
      await a.write(const RecordWrite(
        familyId: 'f1',
        entity: Entities.entry,
        id: 'e1',
        fields: {'title': 'Atta 10kg', 'type': 'need_to_buy'},
      ));
      final s = await a.get(Entities.entry, 'e1');
      expect(s!.fields['title'], 'Atta 10kg');
      expect((await a.versionVector('f1')).keys, ['deviceA']);
    });

    test('two devices editing offline converge after syncing', () async {
      await a.write(const RecordWrite(
        familyId: 'f1',
        entity: Entities.entry,
        id: 'e1',
        fields: {'title': 'Fan not working', 'priority': 'normal'},
      ));
      await syncPair(a, b);

      // Both edit different fields while apart.
      await a.write(const RecordWrite(
        familyId: 'f1', entity: Entities.entry, id: 'e1',
        fields: {'priority': 'urgent'},
      ));
      await b.write(const RecordWrite(
        familyId: 'f1', entity: Entities.entry, id: 'e1',
        fields: {'assigneeId': 'm2'},
      ));
      await syncPair(a, b);

      final sa = (await a.get(Entities.entry, 'e1'))!;
      final sb = (await b.get(Entities.entry, 'e1'))!;
      expect(sa.fields, sb.fields);
      expect(sa.fields['priority'], 'urgent');
      expect(sa.fields['assigneeId'], 'm2');
    });

    test('a second sync sends nothing and re-applying is harmless', () async {
      await a.write(const RecordWrite(
        familyId: 'f1', entity: Entities.entry, id: 'e1',
        fields: {'title': 'Milk'},
      ));
      await syncPair(a, b);
      expect(
        await a.changesSince('f1', await b.versionVector('f1')),
        isEmpty,
      );
      final all = await a.allChanges('f1');
      expect(await b.applyRemote(all), 0);
    });

    test('changes relay A → B → C', () async {
      final c = await RecordStore.open(openMemoryDatabase(), 'deviceC');
      await a.write(const RecordWrite(
        familyId: 'f1', entity: Entities.entry, id: 'e9',
        fields: {'title': 'Pay gas bill'},
      ));
      await syncPair(a, b);
      await syncPair(b, c);
      expect((await c.get(Entities.entry, 'e9'))!.fields['title'],
          'Pay gas bill');
      await c.db.close();
    });

    test('watch emits on local and remote writes', () async {
      final seen = <int>[];
      final sub = b.watch('f1', Entities.entry).listen((l) => seen.add(l.length));
      await a.write(const RecordWrite(
        familyId: 'f1', entity: Entities.entry, id: 'e1',
        fields: {'title': 'Bread'},
      ));
      await syncPair(a, b);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(seen.last, 1);
      await sub.cancel();
    });
  });
}
