import 'package:famboard/data/key_vault.dart';
import 'package:famboard/domain/invite.dart';
import 'package:famboard/domain/models.dart';
import 'package:famboard/domain/views.dart';
import 'package:famboard/services/categorizer/categorizer.dart';
import 'package:famboard/services/notifications.dart';
import 'package:famboard/services/recurrence.dart';
import 'package:famboard/services/text_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

Entry _entry(
  String id, {
  EntryType type = EntryType.needToBuy,
  EntryStatus status = EntryStatus.open,
  DateTime? due,
  Priority priority = Priority.normal,
  String? assignee,
  String? rrule,
  double? amount,
  DateTime? doneAt,
  String category = 'groceries',
  bool deleted = false,
}) =>
    Entry(
      id: id,
      familyId: 'f',
      title: id,
      type: type,
      categoryId: category,
      priority: priority,
      status: status,
      dueAt: due,
      assigneeId: assignee,
      rrule: rrule,
      amount: amount,
      doneAt: doneAt,
      updatedAt: DateTime(2026, 1, 1),
      deleted: deleted,
    );

void main() {
  group('Categorizer', () {
    final c = Categorizer();

    final cases = <String, (EntryType, String)>{
      'atta 10kg': (EntryType.needToBuy, 'groceries.staples'),
      'Doodh 2 litre': (EntryType.needToBuy, 'groceries.dairy'),
      'bathroom tap leaking': (EntryType.repair, 'repairs.plumbing'),
      'fan not working': (EntryType.repair, 'repairs.electrical'),
      'pankha kharab hai': (EntryType.repair, 'repairs.electrical'),
      'pay electricity bill': (EntryType.bill, 'bills.electricity'),
      'jio recharge': (EntryType.bill, 'bills.internet'),
      'school fees': (EntryType.bill, 'bills.fees'),
      'sugar khatam': (EntryType.outOfStock, 'groceries.staples'),
      'printer ink finished': (EntryType.outOfStock, 'upgrades.electronics'),
      'upgrade fridge': (EntryType.upgrade, 'upgrades.appliances'),
      'laptop not working': (EntryType.repair, 'repairs.appliances'),
      'new school shoes': (EntryType.needToBuy, 'kids.uniform'),
      'call plumber': (EntryType.task, 'repairs.plumbing'),
      'दूध': (EntryType.needToBuy, 'groceries.dairy'),
      'tomatos': (EntryType.needToBuy, 'groceries.produce'),
      'AC servicing': (EntryType.repair, 'repairs.appliances'),
    };
    cases.forEach((title, expected) {
      test(title, () {
        final r = c.categorize(title);
        expect((r.type, r.categoryId), expected);
      });
    });

    test('unknown items fall back to the type default', () {
      final r = c.categorize('xyzzy thing');
      expect(r.categoryId, 'groceries');
      expect(r.source, CategorySource.typeDefault);
    });

    test('family overrides win over the dictionary', () {
      final r = c.categorize('milk powder', overrides: const [
        KeywordOverride(term: 'milk powder', categoryId: 'groceries.snacks'),
      ]);
      expect(r.categoryId, 'groceries.snacks');
      expect(r.source, CategorySource.familyOverride);
    });

    test('learnable terms are conservative for long titles', () {
      expect(Categorizer.learnableTerms('Bai salary'), containsAll(['bai salary', 'bai', 'salary']));
      expect(Categorizer.learnableTerms('the red box of big chocolates'), ['the red box of big chocolates']);
    });
  });

  group('RecurrenceRule', () {
    test('round-trips through RRULE text', () {
      for (final r in [
        RecurrenceRule.daily(),
        RecurrenceRule.everyNDays(10),
        RecurrenceRule.weekly(3),
        RecurrenceRule.monthly(10),
        RecurrenceRule.quarterly(5),
        RecurrenceRule.yearly(),
      ]) {
        expect(RecurrenceRule.parse(r.toString()).toString(), r.toString());
      }
    });

    test('monthly on the 31st clamps to short months', () {
      final r = RecurrenceRule.monthly(31);
      expect(r.nextAfter(DateTime(2026, 1, 31)), DateTime(2026, 2, 28));
      expect(r.nextAfter(DateTime(2026, 2, 28), anchor: DateTime(2026, 2, 28)), DateTime(2026, 3, 31));
    });

    test('paying a monthly bill late gives next month, not the past', () {
      final r = RecurrenceRule.monthly(10);
      final next = r.nextDue(due: DateTime(2026, 9, 10), completedOn: DateTime(2026, 10, 30));
      expect(next, DateTime(2026, 11, 10));
    });

    test('paying early still moves to the next period', () {
      final r = RecurrenceRule.monthly(10);
      expect(r.nextDue(due: DateTime(2026, 11, 10), completedOn: DateTime(2026, 11, 5)), DateTime(2026, 12, 10));
    });

    test('weekly lands on the chosen weekday', () {
      final r = RecurrenceRule.weekly(DateTime.saturday);
      final next = r.nextAfter(DateTime(2026, 10, 30)); // Friday
      expect(next.weekday, DateTime.saturday);
      expect(next, DateTime(2026, 10, 31));
    });

    test('quarterly and yearly', () {
      expect(RecurrenceRule.quarterly(15).nextAfter(DateTime(2026, 11, 15)), DateTime(2027, 2, 15));
      expect(RecurrenceRule.yearly().nextAfter(DateTime(2026, 3, 1)), DateTime(2027, 3, 1));
    });
  });

  group('TextExtractor', () {
    final x = TextExtractor(now: () => DateTime(2026, 10, 30, 10));

    test('amount and ordinal due date', () {
      final r = x.extract('pay gas bill 950 by 12th', type: EntryType.bill);
      expect(r.title, 'pay gas bill');
      expect(r.amount, 950);
      expect(r.dueAt, DateTime(2026, 11, 12));
    });

    test('rupee symbols and Indian grouping', () {
      expect(x.extract('rent ₹25,000').amount, 25000);
      expect(x.extract('LIC premium Rs. 1,234.50').amount, 1234.5);
    });

    test('quantities with units', () {
      final r = x.extract('atta 10kg');
      expect(r.title, 'atta');
      expect(r.quantity, 10);
      expect(r.unit, 'kg');
      expect(x.extract('milk 2 litres').unit, 'L');
      expect(x.extract('eggs 1 dozen').unit, 'dozen');
    });

    test('relative dates in English and Hindi', () {
      expect(x.extract('call plumber tomorrow').dueAt, DateTime(2026, 10, 31));
      expect(x.extract('plumber ko bulana kal').dueAt, DateTime(2026, 10, 31));
      expect(x.extract('doctor parso').dueAt, DateTime(2026, 11, 1));
      expect(x.extract('submit form next monday').dueAt, DateTime(2026, 11, 2));
    });

    test('numeric and month-name dates', () {
      expect(x.extract('insurance due 15/11').dueAt, DateTime(2026, 11, 15));
      expect(x.extract('car service on 3 dec').dueAt, DateTime(2026, 12, 3));
      expect(x.extract('renew passport jan 20').dueAt, DateTime(2027, 1, 20));
    });

    test('decimals are not dates', () {
      final r = x.extract('oil 1.5 l');
      expect(r.dueAt, isNull);
      expect(r.quantity, 1.5);
    });
  });

  group('SmsBillParser', () {
    final p = SmsBillParser(now: () => DateTime(2026, 10, 30));

    test('electricity bill SMS', () {
      final b = p.parse(
        'Dear Consumer, your MSEDCL electricity bill of Rs. 1,840.00 for Cons No 1700 '
        'is due on 15-11-2026. Pay online to avoid late fee.',
      )!;
      expect(b.categoryId, 'bills.electricity');
      expect(b.amount, 1840);
      expect(b.dueAt, DateTime(2026, 11, 15));
    });

    test('credit card SMS with month name', () {
      final b = p.parse(
        'Your HDFC Bank Credit Card ending 4417 statement: Total Amount Due INR 12,450.75, '
        'Min Amt Due INR 620. Pay by 18 Nov 2026.',
      )!;
      expect(b.categoryId, 'bills.card');
      expect(b.amount, 12450.75);
      expect(b.dueAt, DateTime(2026, 11, 18));
    });

    test('ignores non-bill messages', () {
      expect(p.parse('Your OTP is 482913. Do not share it.'), isNull);
      expect(p.parse('Happy Diwali from all of us!'), isNull);
    });
  });

  group('Views', () {
    final now = DateTime(2026, 10, 30, 9);

    test('Today sections are ordered and de-duplicated', () {
      final v = TodayView.build([
        _entry('overdue', due: DateTime(2026, 10, 28), type: EntryType.repair, priority: Priority.urgent),
        _entry('today', due: DateTime(2026, 10, 30)),
        _entry('urgent', type: EntryType.repair, priority: Priority.high),
        _entry('stock', type: EntryType.outOfStock),
        _entry('mine', assignee: 'me', type: EntryType.task),
        _entry('soon', due: DateTime(2026, 11, 3), type: EntryType.task),
        _entry('later', due: DateTime(2026, 12, 25)),
        _entry('done', status: EntryStatus.done, due: DateTime(2026, 10, 29)),
      ], now: now, meId: 'me');
      expect(v.overdue.map((e) => e.id), ['overdue']);
      expect(v.dueToday.map((e) => e.id), ['today']);
      expect(v.urgentRepairs.map((e) => e.id), ['urgent']);
      expect(v.outOfStock.map((e) => e.id), ['stock']);
      expect(v.mine.map((e) => e.id), ['mine']);
      expect(v.upcoming.map((e) => e.id), ['soon']);
      expect(v.shoppingCount, 3);
    });

    test('schedule buckets', () {
      final monthly = _entry('rent', rrule: 'FREQ=MONTHLY;BYMONTHDAY=5', due: DateTime(2026, 11, 5));
      final inTenDays = _entry('ten', due: DateTime(2026, 11, 9));
      expect(inBucket(monthly, ListBucket.monthly, now), isTrue);
      expect(inBucket(monthly, ListBucket.weekly, now), isFalse);
      expect(inBucket(monthly, ListBucket.recurring, now), isTrue);
      expect(inBucket(inTenDays, ListBucket.weekly, now), isFalse);
      expect(inBucket(inTenDays, ListBucket.monthly, now), isTrue);
      expect(inBucket(_entry('x', deleted: true), ListBucket.deleted, now), isTrue);
    });

    test('bill totals', () {
      final v = BillsView.build([
        _entry('elec', type: EntryType.bill, amount: 1800, due: DateTime(2026, 10, 31)),
        _entry('next', type: EntryType.bill, amount: 999, due: DateTime(2026, 11, 3)),
        _entry('paid', type: EntryType.bill, amount: 500, status: EntryStatus.done, doneAt: DateTime(2026, 10, 2)),
        _entry('oldpaid', type: EntryType.bill, amount: 700, status: EntryStatus.done, doneAt: DateTime(2026, 9, 2)),
      ], now: now);
      expect(v.stillToPayThisMonth, 1800);
      expect(v.paidThisMonth, 500);
      expect(v.upcoming.map((e) => e.id), ['elec', 'next']);
    });

    test('shopping groups follow store-section order', () {
      final groups = shoppingGroups([
        _entry('soap', category: 'household.toiletries'),
        _entry('onion', category: 'groceries.produce'),
        _entry('milk', category: 'groceries.dairy'),
        _entry('fan', type: EntryType.repair, category: 'repairs'),
      ]);
      expect(groups.map((g) => g.$1), ['groceries.produce', 'groceries.dairy', 'household.toiletries']);
    });
  });

  group('Invite', () {
    test('round-trips and expires', () {
      final invite = FamilyInvite(
        familyId: 'fam-1',
        familyName: 'शर्मा परिवार',
        key: KeyVault.randomKey(),
        role: Role.child,
        invitedBy: 'm1',
        expiresAt: DateTime(2026, 10, 30, 10, 15),
      );
      final back = FamilyInvite.decode(invite.encode());
      expect(back.familyName, 'शर्मा परिवार');
      expect(back.role, Role.child);
      expect(back.key, invite.key);
      expect(back.isExpired(DateTime(2026, 10, 30, 10, 14)), isFalse);
      expect(back.isExpired(DateTime(2026, 10, 30, 10, 16)), isTrue);
      expect(() => FamilyInvite.decode('hello'), throwsFormatException);
    });
  });

  group('ReminderPlanner', () {
    test('plans due-day and early reminders for open entries only', () {
      final texts = ReminderTexts(
        channelName: 'r',
        dueToday: (t) => 'today $t',
        dueIn: (t, d) => '$t in $d',
        digestTitle: 'd',
        digestBody: 'b',
      );
      final plan = const ReminderPlanner().plan(
        entries: [
          _entry('elec', type: EntryType.bill, due: DateTime(2026, 11, 10)),
          _entry('past', due: DateTime(2026, 10, 1)),
          _entry('closed', status: EntryStatus.done, due: DateTime(2026, 11, 10)),
        ],
        now: DateTime(2026, 10, 30, 12),
        billLeadDays: 3,
        texts: texts,
      );
      expect(plan.map((r) => r.title), ['elec in 3', 'today elec']);
      expect(plan.first.at, DateTime(2026, 11, 7, 9));
    });
  });
}
