import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../data/settings_store.dart';
import '../../ui/format.dart';
import '../../ui/l10n_ext.dart';
import '../../ui/widgets.dart';
import 'backup_flow.dart';

const appVersion = '0.2.4';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final services = ref.watch(servicesProvider);
    final settings = services.settings;
    String? v(String key) => ref.watch(settingProvider(key)).value;

    final locale = v(SettingsStore.kLocale);
    final large = v(SettingsStore.kLargeText) == 'true';
    final notifications = v(SettingsStore.kNotifications) != 'false';
    final digest = v(SettingsStore.kDigestTime) ?? '08:00';
    final billLead = int.tryParse(v(SettingsStore.kBillLeadDays) ?? '') ?? 3;
    final nearby = v(SettingsStore.kNearby) != 'false';
    final deviceName = v(SettingsStore.kDeviceName) ?? '';
    final session = ref.watch(sessionProvider);
    final lastBackupRaw = session == null ? null : v('lastBackup.${session.familyId}');
    final lastBackup = lastBackupRaw == null ? null : DateTime.tryParse(lastBackupRaw);

    Widget header(String t) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(t, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        );

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          header(l.settingsLanguage),
          RadioGroup<String>(
            groupValue: locale ?? '',
            onChanged: (val) => settings.set(SettingsStore.kLocale, val == '' ? null : val),
            child: Column(
              children: [
                RadioListTile<String>(value: '', title: Text(l.languageSystem)),
                RadioListTile<String>(value: 'en', title: Text(l.languageEnglish)),
                RadioListTile<String>(value: 'hi', title: Text(l.languageHindi)),
              ],
            ),
          ),
          SwitchListTile(
            title: Text(l.settingsLargeText),
            subtitle: Text(l.settingsLargeTextBody),
            value: large,
            onChanged: (val) => settings.set(SettingsStore.kLargeText, '$val'),
          ),
          header(l.settingsReminders),
          SwitchListTile(
            title: Text(l.settingsNotifications),
            value: notifications,
            onChanged: (val) async {
              if (val) await services.notifications.requestPermission();
              await settings.set(SettingsStore.kNotifications, '$val');
            },
          ),
          ListTile(
            title: Text(l.settingsDigestTime),
            trailing: Text(digest),
            enabled: notifications,
            onTap: () async {
              final parts = digest.split(':');
              final t = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
              );
              if (t != null) {
                await settings.set(
                  SettingsStore.kDigestTime,
                  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                );
              }
            },
          ),
          ListTile(
            title: Text(l.settingsBillLead),
            enabled: notifications,
            trailing: DropdownButton<int>(
              value: billLead,
              underline: const SizedBox.shrink(),
              items: [
                for (final d in [0, 1, 2, 3, 5, 7])
                  DropdownMenuItem(value: d, child: Text(d == 0 ? l.reminderNone : l.reminderDaysBefore(d))),
              ],
              onChanged: notifications
                  ? (d) => settings.set(SettingsStore.kBillLeadDays, '${d ?? 3}')
                  : null,
            ),
          ),
          header(l.syncTitle),
          ListTile(
            title: Text(l.settingsPhoneName),
            subtitle: Text('$deviceName\n${l.settingsPhoneNameBody}'),
            isThreeLine: true,
            trailing: const Icon(Icons.edit_outlined),
            onTap: () async {
              final name = await _ask(context, l.settingsPhoneName, deviceName);
              if (name != null && name.trim().isNotEmpty) {
                await settings.set(SettingsStore.kDeviceName, name.trim());
              }
            },
          ),
          if (Platform.isAndroid)
            SwitchListTile(
              title: Text(l.settingsNearby),
              subtitle: Text(l.settingsNearbyBody),
              value: nearby,
              onChanged: (val) async {
                if (val) await ref.read(servicesProvider).health.checker.requestPermissions();
                await settings.set(SettingsStore.kNearby, '$val');
                if (context.mounted) showSnack(context, l.settingsNeedsRestart);
              },
            ),
          header(l.settingsData),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: Text(l.exportCsv),
            onTap: () => _export(context, ref, csv: true),
          ),
          ListTile(
            leading: const Icon(Icons.data_object),
            title: Text(l.exportJson),
            onTap: () => _export(context, ref, csv: false),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(l.backupCreate),
            subtitle: lastBackup == null
                ? Text(l.backupNever)
                : Text(l.backupLast(formatDate(context, lastBackup))),
            onTap: () => createBackupFlow(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.settings_backup_restore),
            title: Text(l.backupRestore),
            onTap: () => pickAndRestoreBackup(context, ref),
          ),
          header(l.settingsAbout),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l.appTitle),
            subtitle: Text(l.aboutBody(appVersion)),
          ),
        ],
      ),
    );
  }

  Future<String?> _ask(BuildContext context, String title, String initial, {bool secret = false}) async {
    final l = context.l10n;
    final c = TextEditingController(text: initial);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          obscureText: secret,
          decoration: InputDecoration(helperText: secret ? l.backupPassphraseHint : null, helperMaxLines: 2),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.continueAction)),
        ],
      ),
    );
    return ok == true ? c.text : null;
  }

  Future<void> _shareFile(String name, List<int> bytes, String mime) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: mime)]));
  }

  Future<void> _export(BuildContext context, WidgetRef ref, {required bool csv}) async {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    final backup = ref.read(servicesProvider).backup;
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    try {
      if (csv) {
        final text = await backup.exportCsv(session.familyId);
        // BOM so Excel opens Devanagari text correctly.
        await _shareFile('famboard-$stamp.csv', [0xEF, 0xBB, 0xBF, ...utf8.encode(text)], 'text/csv');
      } else {
        final text = await backup.exportJson(session.familyId);
        await _shareFile('famboard-$stamp.json', utf8.encode(text), 'application/json');
      }
    } catch (e) {
      if (context.mounted) showSnack(context, context.l10n.genericError);
    }
  }




}
