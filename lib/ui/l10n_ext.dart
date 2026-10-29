import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/categories.dart';
import '../domain/models.dart';
import '../l10n/app_localizations.dart';
import '../services/recurrence.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  Locale get locale => Localizations.localeOf(this);
  String get localeTag => locale.languageCode == 'hi' ? 'hi_IN' : 'en_IN';
}

extension EntryTypeL10n on EntryType {
  String label(AppLocalizations l) => switch (this) {
        EntryType.needToBuy => l.typeNeedToBuy,
        EntryType.outOfStock => l.typeOutOfStock,
        EntryType.repair => l.typeRepair,
        EntryType.upgrade => l.typeUpgrade,
        EntryType.bill => l.typeBill,
        EntryType.task => l.typeTask,
      };

  IconData get icon => switch (this) {
        EntryType.needToBuy => Icons.shopping_basket_outlined,
        EntryType.outOfStock => Icons.inventory_2_outlined,
        EntryType.repair => Icons.handyman_outlined,
        EntryType.upgrade => Icons.auto_awesome_outlined,
        EntryType.bill => Icons.receipt_long_outlined,
        EntryType.task => Icons.check_circle_outline,
      };
}

extension StatusL10n on EntryStatus {
  String label(AppLocalizations l) => switch (this) {
        EntryStatus.proposed => l.statusProposed,
        EntryStatus.open => l.statusOpen,
        EntryStatus.inProgress => l.statusInProgress,
        EntryStatus.done => l.statusDone,
        EntryStatus.cancelled => l.statusCancelled,
      };
}

extension PriorityL10n on Priority {
  String label(AppLocalizations l) => switch (this) {
        Priority.low => l.priorityLow,
        Priority.normal => l.priorityNormal,
        Priority.high => l.priorityHigh,
        Priority.urgent => l.priorityUrgent,
      };
}

extension RoleL10n on Role {
  String label(AppLocalizations l) => switch (this) {
        Role.admin => l.roleAdmin,
        Role.member => l.roleMember,
        Role.child => l.roleChild,
        Role.viewer => l.roleViewer,
      };

  String description(AppLocalizations l) => switch (this) {
        Role.admin => l.roleAdminDesc,
        Role.member => l.roleMemberDesc,
        Role.child => l.roleChildDesc,
        Role.viewer => l.roleViewerDesc,
      };
}

String categoryName(BuildContext context, String id, {List<CustomCategory> custom = const []}) =>
    categoryById(id, custom: custom).name(context.locale);

/// Human description of a recurrence rule.
String describeRule(BuildContext context, String? rrule) {
  final l = context.l10n;
  final rule = RecurrenceRule.tryParse(rrule);
  if (rule == null) return l.repeatNever;
  switch (rule.freq) {
    case Freq.daily:
      return rule.interval == 1 ? l.repeatDaily : l.everyNDays(rule.interval);
    case Freq.weekly:
      if (rule.interval != 1) return l.everyNWeeks(rule.interval);
      if (rule.byWeekday != null) {
        final day = DateFormat.EEEE(context.localeTag)
            .format(DateTime(2024, 1, rule.byWeekday!)); // 2024-01-01 is a Monday
        return l.weeklyOn(day);
      }
      return l.repeatWeekly;
    case Freq.monthly:
      if (rule.interval == 3) return l.repeatQuarterly;
      if (rule.interval != 1) return l.everyNMonths(rule.interval);
      return rule.byMonthDay == null ? l.repeatMonthly : l.monthlyOnDay(rule.byMonthDay!);
    case Freq.yearly:
      return l.repeatYearly;
  }
}
