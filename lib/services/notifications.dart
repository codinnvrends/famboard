import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/models.dart' hide Priority;

/// Localised notification text, built from the app's strings.
class ReminderTexts {
  const ReminderTexts({
    required this.channelName,
    required this.dueToday,
    required this.dueIn,
    required this.digestTitle,
    required this.digestBody,
  });

  final String channelName;
  final String Function(String title) dueToday;
  final String Function(String title, int days) dueIn;
  final String digestTitle;
  final String digestBody;
}

/// A reminder to schedule.
class PlannedReminder {
  const PlannedReminder({required this.id, required this.at, required this.title, required this.body});
  final int id;
  final DateTime at;
  final String title;
  final String body;
}

/// Plans reminders from entries. Pure, so it is unit-tested.
class ReminderPlanner {
  const ReminderPlanner({this.hour = 9, this.horizonDays = 60, this.max = 50});

  final int hour;
  final int horizonDays;

  /// iOS keeps at most 64 pending notifications; stay under it.
  final int max;

  List<PlannedReminder> plan({
    required List<Entry> entries,
    required DateTime now,
    required int billLeadDays,
    required ReminderTexts texts,
  }) {
    final out = <PlannedReminder>[];
    final horizon = now.add(Duration(days: horizonDays));
    for (final e in entries) {
      final due = e.dueAt;
      if (!e.isOpen || due == null) continue;
      final dueAt = DateTime(due.year, due.month, due.day, hour);
      if (dueAt.isAfter(horizon)) continue;
      if (dueAt.isAfter(now)) {
        out.add(PlannedReminder(
          id: _id(e.id, 0),
          at: dueAt,
          title: texts.dueToday(e.title),
          body: e.title,
        ));
      }
      final lead = e.leadDays ?? (e.type == EntryType.bill ? billLeadDays : 0);
      if (lead > 0) {
        final early = dueAt.subtract(Duration(days: lead));
        if (early.isAfter(now)) {
          out.add(PlannedReminder(
            id: _id(e.id, 1),
            at: early,
            title: texts.dueIn(e.title, lead),
            body: e.title,
          ));
        }
      }
    }
    out.sort((a, b) => a.at.compareTo(b.at));
    return out.take(max).toList();
  }

  static int _id(String entryId, int kind) =>
      (entryId.hashCode & 0x0fffffff) * 2 + kind + 10;
}

/// Local, offline reminders and the daily digest (spec FR-22, FR-23).
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;
  static const _digestId = 1;
  static const _channelId = 'famboard_reminders';

  Future<void> init() async {
    if (kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));
    } catch (e) {
      debugPrint('Timezone setup failed, using UTC: $e');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  Future<bool> requestPermission() async {
    if (!_ready) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
  }

  NotificationDetails _details(String channelName) => NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      );

  /// Replaces all scheduled reminders with a fresh plan.
  Future<void> reschedule({
    required List<Entry> entries,
    required bool enabled,
    required int billLeadDays,
    required TimeOfDay digestTime,
    required ReminderTexts texts,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
      if (!enabled) return;
      final details = _details(texts.channelName);
      final now = DateTime.now();
      final plan = const ReminderPlanner().plan(
        entries: entries,
        now: now,
        billLeadDays: billLeadDays,
        texts: texts,
      );
      for (final r in plan) {
        await _plugin.zonedSchedule(
          id: r.id,
          scheduledDate: tz.TZDateTime.from(r.at, tz.local),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: r.title,
          body: r.body,
        );
      }
      var digest = DateTime(now.year, now.month, now.day, digestTime.hour, digestTime.minute);
      if (!digest.isAfter(now)) digest = digest.add(const Duration(days: 1));
      await _plugin.zonedSchedule(
        id: _digestId,
        scheduledDate: tz.TZDateTime.from(digest, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: texts.digestTitle,
        body: texts.digestBody,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint('Scheduling reminders failed: $e');
    }
  }
}
