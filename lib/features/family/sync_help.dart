import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../data/settings_store.dart';
import '../../l10n/app_localizations.dart';
import '../../sync/sync_health.dart';
import '../../sync/sync_manager.dart';
import '../../ui/l10n_ext.dart';
import '../../ui/widgets.dart';

String problemText(AppLocalizations l, SyncProblem p) => switch (p) {
      SyncProblem.nearbyPermission => l.problemNearbyPermission,
      SyncProblem.locationPermission => l.problemLocationPermission,
      SyncProblem.locationOff => l.problemLocationOff,
      SyncProblem.bluetoothOff => l.problemBluetoothOff,
      SyncProblem.noWifi => l.problemNoWifi,
    };

IconData problemIcon(SyncProblem p) => switch (p) {
      SyncProblem.nearbyPermission => Icons.bluetooth_searching,
      SyncProblem.locationPermission => Icons.location_on_outlined,
      SyncProblem.locationOff => Icons.location_off_outlined,
      SyncProblem.bluetoothOff => Icons.bluetooth_disabled,
      SyncProblem.noWifi => Icons.wifi_off,
    };

/// Shown on the Family tab when something on this phone blocks sync, with
/// one-tap fixes.
class SyncProblemsCard extends ConsumerWidget {
  const SyncProblemsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final health = ref.watch(syncHealthProvider).value ?? SyncHealth.ok;
    if (health.isOk) return const SizedBox.shrink();
    final services = ref.read(servicesProvider);

    Future<void> recheck() async {
      await services.health.refresh();
      await services.sync.retryTransports();
      await services.sync.syncAll(force: true);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.55),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.syncFixTitle, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              for (final p in health.problems)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(problemIcon(p), size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(problemText(l, p))),
                    ],
                  ),
                ),
              Wrap(
                spacing: 8,
                children: [
                  if (health.needsPermissions)
                    FilledButton(
                      onPressed: () async {
                        await services.health.checker.requestPermissions();
                        await recheck();
                      },
                      child: Text(l.allowPermissions),
                    ),
                  OutlinedButton(
                    onPressed: () => services.health.checker.openAppSettings(),
                    child: Text(l.openSettings),
                  ),
                  TextButton(onPressed: recheck, child: Text(l.checkAgain)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Everything needed to understand why two phones aren't syncing.
Future<void> showSyncDiagnostics(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _Diagnostics(),
    );

class _Diagnostics extends ConsumerWidget {
  const _Diagnostics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final services = ref.watch(servicesProvider);
    final status = ref.watch(syncStatusProvider).value;
    final health = ref.watch(syncHealthProvider).value ?? SyncHealth.ok;
    final deviceName = ref.watch(settingProvider(SettingsStore.kDeviceName)).value ?? '';
    final names = {'wifi': l.viaWifi, 'nearby': l.viaNearby};
    final methods = services.sync.transports.map((t) => t.name).toList();

    String time(DateTime t) =>
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

    String report() {
      final b = StringBuffer()
        ..writeln('FamBoard sync report')
        ..writeln('Phone: $deviceName (${services.deviceId})')
        ..writeln('Running: ${status?.running}')
        ..writeln('Problems: ${health.problems.map((p) => p.name).join(', ')}');
      for (final m in methods) {
        b.writeln('$m: ${status?.transports.contains(m) == true ? 'running' : 'off'} ${status?.transportErrors[m] ?? ''}');
      }
      b.writeln('Peers: ${status?.peers.map((p) => '${p.deviceId}/${p.transport}').join(', ')}');
      b.writeln('Last error: ${status?.lastError ?? '-'}');
      for (final line in status?.log ?? const <SyncLogLine>[]) {
        b.writeln('${time(line.at)} ${line.message}');
      }
      return b.toString();
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(l.syncDiagnostics, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(l.diagHint, style: theme.textTheme.bodySmall),
          SectionHeader(l.diagThisPhone),
          Text('$deviceName · ${services.deviceId}', style: theme.textTheme.bodyMedium),
          SectionHeader(l.diagMethods),
          for (final m in methods)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                status?.transports.contains(m) == true ? Icons.check_circle : Icons.error_outline,
                color: status?.transports.contains(m) == true ? theme.colorScheme.primary : theme.colorScheme.error,
              ),
              title: Text(names[m] ?? m),
              subtitle: Text(
                status?.transports.contains(m) == true
                    ? l.diagRunning
                    : '${l.diagNotRunning}${status?.transportErrors[m] == null ? '' : ': ${status!.transportErrors[m]}'}',
              ),
            ),
          if (health.problems.isNotEmpty)
            for (final p in health.problems)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(problemIcon(p), color: theme.colorScheme.error),
                title: Text(problemText(l, p)),
              ),
          SectionHeader(l.diagPhonesSeen),
          if (status?.peers.isEmpty ?? true)
            Text(l.diagNone)
          else
            for (final p in status!.peers)
              Text('${p.name ?? p.deviceId} · ${names[p.transport] ?? p.transport}'),
          if (status?.lastError != null) ...[
            SectionHeader(l.diagLastError),
            Text(status!.lastError!, style: theme.textTheme.bodySmall),
          ],
          SectionHeader(l.diagRecent),
          for (final line in status?.log ?? const <SyncLogLine>[])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${time(line.at)}  ${line.message}',
                style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.copy),
            label: Text(l.diagCopy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: report()));
              if (context.mounted) showSnack(context, l.copied);
            },
          ),
        ],
      ),
    );
  }
}
