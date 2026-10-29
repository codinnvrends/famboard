import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/models.dart';
import '../domain/views.dart';
import 'l10n_ext.dart';

/// ₹ with Indian digit grouping (1,23,456).
String formatMoney(double amount) {
  final f = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: amount == amount.roundToDouble() ? 0 : 2,
  );
  return f.format(amount);
}

String formatQuantity(double? q, String? unit) {
  if (q == null) return '';
  final n = q == q.roundToDouble() ? q.toInt().toString() : q.toString();
  return unit == null ? n : '$n $unit';
}

String formatDate(BuildContext context, DateTime d) {
  final now = DateTime.now();
  final pattern = d.year == now.year ? DateFormat.MMMd(context.localeTag) : DateFormat.yMMMd(context.localeTag);
  return pattern.format(d);
}

/// "Due today", "Due tomorrow", "3 days overdue", "Due Nov 12".
String dueLabel(BuildContext context, Entry e, {DateTime? now}) {
  final l = context.l10n;
  final days = daysUntilDue(e, now ?? DateTime.now());
  if (days == null) return '';
  if (days < 0) return l.overdueBy(-days);
  if (days == 0) return l.dueTodayShort;
  if (days == 1) return l.dueTomorrow;
  return l.dueOn(formatDate(context, e.dueAt!));
}

String timeAgo(BuildContext context, DateTime t) {
  final l = context.l10n;
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return l.justNow;
  if (d.inHours < 1) return l.minutesAgo(d.inMinutes);
  if (d.inDays < 1) return l.hoursAgo(d.inHours);
  return l.daysAgo(d.inDays);
}

String transportLabel(BuildContext context, String transport) => switch (transport) {
      'wifi' => context.l10n.viaWifi,
      'nearby' => context.l10n.viaNearby,
      _ => context.l10n.viaOther,
    };
