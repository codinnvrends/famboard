import '../services/recurrence.dart';
import 'categories.dart';
import 'models.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Days from [today] to the entry's due date (negative = overdue).
int? daysUntilDue(Entry e, DateTime today) {
  final due = e.dueAt;
  if (due == null) return null;
  return dateOnly(due).difference(dateOnly(today)).inDays;
}

/// Default ordering: overdue and soonest first, then priority, then newest.
int compareEntries(Entry a, Entry b) {
  final ad = a.dueAt, bd = b.dueAt;
  if (ad != null && bd != null) {
    final c = ad.compareTo(bd);
    if (c != 0) return c;
  } else if (ad != null) {
    return -1;
  } else if (bd != null) {
    return 1;
  }
  final p = b.priority.index.compareTo(a.priority.index);
  if (p != 0) return p;
  return b.updatedAt.compareTo(a.updatedAt);
}

/// Sections on the Today screen, de-duplicated top to bottom.
class TodayView {
  TodayView({
    required this.overdue,
    required this.dueToday,
    required this.urgentRepairs,
    required this.outOfStock,
    required this.mine,
    required this.upcoming,
    required this.shoppingCount,
  });

  final List<Entry> overdue;
  final List<Entry> dueToday;
  final List<Entry> urgentRepairs;
  final List<Entry> outOfStock;
  final List<Entry> mine;
  final List<Entry> upcoming;
  final int shoppingCount;

  bool get isEmpty =>
      overdue.isEmpty &&
      dueToday.isEmpty &&
      urgentRepairs.isEmpty &&
      outOfStock.isEmpty &&
      mine.isEmpty &&
      upcoming.isEmpty;

  factory TodayView.build(List<Entry> entries, {required DateTime now, required String meId}) {
    final open = entries.where((e) => e.isOpen).toList()..sort(compareEntries);
    final used = <String>{};
    List<Entry> take(bool Function(Entry) test) {
      final out = <Entry>[];
      for (final e in open) {
        if (used.contains(e.id) || !test(e)) continue;
        used.add(e.id);
        out.add(e);
      }
      return out;
    }

    final overdue = take((e) => (daysUntilDue(e, now) ?? 1) < 0);
    final today = take((e) => daysUntilDue(e, now) == 0);
    final urgent = take((e) => e.type == EntryType.repair && e.priority.isHighOrAbove);
    final stock = take((e) => e.type == EntryType.outOfStock);
    final mine = take((e) => e.assigneeId == meId);
    final upcoming = take((e) {
      final d = daysUntilDue(e, now);
      return d != null && d >= 1 && d <= 7;
    });
    return TodayView(
      overdue: overdue,
      dueToday: today,
      urgentRepairs: urgent,
      outOfStock: stock,
      mine: mine,
      upcoming: upcoming,
      shoppingCount: open.where((e) => e.type.isShopping).length,
    );
  }
}

/// The schedule lists (spec FR-30).
enum ListBucket { allOpen, daily, weekly, monthly, yearly, recurring, done, deleted }

bool inBucket(Entry e, ListBucket bucket, DateTime now) {
  if (bucket == ListBucket.deleted) return e.deleted;
  if (e.deleted) return false;
  if (bucket == ListBucket.done) return e.status.isClosed;
  if (!e.isOpen) return false;
  final rule = RecurrenceRule.tryParse(e.rrule);
  final days = daysUntilDue(e, now);
  return switch (bucket) {
    ListBucket.allOpen => true,
    ListBucket.recurring => rule != null,
    ListBucket.daily => rule?.freq == Freq.daily || (rule == null && days != null && days <= 0),
    ListBucket.weekly => rule?.freq == Freq.weekly || (rule == null && days != null && days <= 7),
    ListBucket.monthly => rule?.freq == Freq.monthly || (rule == null && days != null && days <= 31),
    ListBucket.yearly => rule?.freq == Freq.yearly || (rule == null && days != null && days <= 366),
    _ => false,
  };
}

/// Filters chosen on the Lists screen.
class EntryFilter {
  const EntryFilter({
    this.types = const {},
    this.topCategories = const {},
    this.assignees = const {},
    this.priorities = const {},
  });

  final Set<EntryType> types;
  final Set<String> topCategories;
  final Set<String> assignees;
  final Set<Priority> priorities;

  bool get isEmpty =>
      types.isEmpty && topCategories.isEmpty && assignees.isEmpty && priorities.isEmpty;

  bool matches(Entry e) =>
      (types.isEmpty || types.contains(e.type)) &&
      (topCategories.isEmpty || topCategories.contains(e.categoryId.split('.').first)) &&
      (assignees.isEmpty || assignees.contains(e.assigneeId ?? '')) &&
      (priorities.isEmpty || priorities.contains(e.priority));

  EntryFilter copyWith({
    Set<EntryType>? types,
    Set<String>? topCategories,
    Set<String>? assignees,
    Set<Priority>? priorities,
  }) =>
      EntryFilter(
        types: types ?? this.types,
        topCategories: topCategories ?? this.topCategories,
        assignees: assignees ?? this.assignees,
        priorities: priorities ?? this.priorities,
      );
}

/// Bills screen numbers (spec FR-33).
class BillsView {
  BillsView({
    required this.upcoming,
    required this.paidRecently,
    required this.stillToPayThisMonth,
    required this.paidThisMonth,
  });

  final List<Entry> upcoming;
  final List<Entry> paidRecently;
  final double stillToPayThisMonth;
  final double paidThisMonth;

  factory BillsView.build(List<Entry> entries, {required DateTime now}) {
    final bills = entries.where((e) => e.type == EntryType.bill && !e.deleted).toList();
    final upcoming = bills.where((e) => e.isOpen).toList()..sort(compareEntries);
    final monthEnd = DateTime(now.year, now.month + 1, 1);
    final monthStart = DateTime(now.year, now.month, 1);
    final toPay = upcoming
        .where((e) => e.dueAt == null || e.dueAt!.isBefore(monthEnd))
        .fold<double>(0, (s, e) => s + (e.amount ?? 0));
    final paid = bills
        .where((e) => e.status == EntryStatus.done && e.doneAt != null)
        .toList()
      ..sort((a, b) => b.doneAt!.compareTo(a.doneAt!));
    final paidThisMonth = paid
        .where((e) => !e.doneAt!.isBefore(monthStart))
        .fold<double>(0, (s, e) => s + (e.amount ?? 0));
    return BillsView(
      upcoming: upcoming,
      paidRecently: paid.take(10).toList(),
      stillToPayThisMonth: toPay,
      paidThisMonth: paidThisMonth,
    );
  }
}

/// Shopping mode: open buy/out-of-stock items grouped by store section.
List<(String, List<Entry>)> shoppingGroups(List<Entry> entries) {
  final items = entries.where((e) => e.isOpen && e.type.isShopping).toList();
  final groups = <String, List<Entry>>{};
  for (final e in items) {
    groups.putIfAbsent(e.categoryId, () => []).add(e);
  }
  final keys = groups.keys.toList()
    ..sort((a, b) => categoryOrder(a).compareTo(categoryOrder(b)));
  return [
    for (final k in keys)
      (k, groups[k]!..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()))),
  ];
}
