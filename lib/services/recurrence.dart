/// Recurrence rules: a small, well-tested subset of RFC 5545 RRULE
/// (FREQ, INTERVAL, BYMONTHDAY, BYDAY) that covers every preset in the spec.
enum Freq { daily, weekly, monthly, yearly }

class RecurrenceRule {
  const RecurrenceRule({
    required this.freq,
    this.interval = 1,
    this.byMonthDay,
    this.byWeekday,
  }) : assert(interval >= 1);

  final Freq freq;
  final int interval;

  /// Day of month for monthly/yearly rules (1–31; clamps in short months).
  final int? byMonthDay;

  /// ISO weekday for weekly rules (1 = Monday … 7 = Sunday).
  final int? byWeekday;

  static const _days = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

  // Presets (spec FR-20).
  factory RecurrenceRule.daily() => const RecurrenceRule(freq: Freq.daily);
  factory RecurrenceRule.everyNDays(int n) =>
      RecurrenceRule(freq: Freq.daily, interval: n);
  factory RecurrenceRule.weekly(int weekday) =>
      RecurrenceRule(freq: Freq.weekly, byWeekday: weekday);
  factory RecurrenceRule.monthly(int day) =>
      RecurrenceRule(freq: Freq.monthly, byMonthDay: day);
  factory RecurrenceRule.quarterly(int day) =>
      RecurrenceRule(freq: Freq.monthly, interval: 3, byMonthDay: day);
  factory RecurrenceRule.yearly() => const RecurrenceRule(freq: Freq.yearly);

  static RecurrenceRule? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      return RecurrenceRule.parse(value);
    } on FormatException {
      return null;
    }
  }

  factory RecurrenceRule.parse(String value) {
    final parts = <String, String>{};
    for (final p in value.replaceFirst('RRULE:', '').split(';')) {
      final kv = p.split('=');
      if (kv.length == 2) parts[kv[0].trim().toUpperCase()] = kv[1].trim();
    }
    final freq = switch (parts['FREQ']?.toUpperCase()) {
      'DAILY' => Freq.daily,
      'WEEKLY' => Freq.weekly,
      'MONTHLY' => Freq.monthly,
      'YEARLY' => Freq.yearly,
      _ => throw FormatException('Unsupported FREQ in $value'),
    };
    final interval = int.tryParse(parts['INTERVAL'] ?? '1') ?? 1;
    final monthDay = int.tryParse(parts['BYMONTHDAY'] ?? '');
    final byDay = parts['BYDAY']?.toUpperCase();
    final weekday = byDay == null ? null : _days.indexOf(byDay) + 1;
    return RecurrenceRule(
      freq: freq,
      interval: interval < 1 ? 1 : interval,
      byMonthDay: monthDay,
      byWeekday: weekday == null || weekday < 1 ? null : weekday,
    );
  }

  @override
  String toString() {
    final b = StringBuffer('FREQ=${freq.name.toUpperCase()}');
    if (interval != 1) b.write(';INTERVAL=$interval');
    if (byMonthDay != null) b.write(';BYMONTHDAY=$byMonthDay');
    if (byWeekday != null) b.write(';BYDAY=${_days[byWeekday! - 1]}');
    return b.toString();
  }

  /// First occurrence strictly after [after] (dates only), anchored on
  /// [anchor] (usually the current due date).
  DateTime nextAfter(DateTime after, {DateTime? anchor}) {
    final base = _date(anchor ?? after);
    final limit = _date(after);
    var candidate = _step(base);
    var guard = 0;
    while (!candidate.isAfter(limit)) {
      candidate = _step(candidate);
      if (++guard > 5000) break;
    }
    return candidate;
  }

  /// The next due date once an occurrence due on [due] is completed on
  /// [completedOn]: the first occurrence after the due date that is not in
  /// the past.
  DateTime nextDue({required DateTime? due, required DateTime completedOn}) {
    final today = _date(completedOn);
    final anchor = due == null ? today : _date(due);
    var next = nextAfter(anchor, anchor: anchor);
    var guard = 0;
    while (next.isBefore(today)) {
      next = nextAfter(next, anchor: next);
      if (++guard > 5000) break;
    }
    return next;
  }

  DateTime _step(DateTime d) {
    switch (freq) {
      case Freq.daily:
        return DateTime(d.year, d.month, d.day + interval);
      case Freq.weekly:
        if (byWeekday != null && d.weekday != byWeekday) {
          final delta = (byWeekday! - d.weekday + 7) % 7;
          return DateTime(d.year, d.month, d.day + delta);
        }
        return DateTime(d.year, d.month, d.day + 7 * interval);
      case Freq.monthly:
        final day = byMonthDay ?? d.day;
        final monthIndex = d.month - 1 + interval;
        final year = d.year + monthIndex ~/ 12;
        final month = monthIndex % 12 + 1;
        return DateTime(year, month, _clampDay(year, month, day));
      case Freq.yearly:
        final day = byMonthDay ?? d.day;
        final year = d.year + interval;
        return DateTime(year, d.month, _clampDay(year, d.month, day));
    }
  }

  static int _clampDay(int year, int month, int day) {
    final last = DateTime(year, month + 1, 0).day;
    return day > last ? last : day;
  }

  static DateTime _date(DateTime d) => DateTime(d.year, d.month, d.day);
}
