import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/settings_store.dart';
import '../../domain/models.dart';
import '../../ui/format.dart';
import '../../ui/l10n_ext.dart';
import '../../ui/widgets.dart';
import 'sync_help.dart';

class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);
    if (session == null) return const SizedBox.shrink();
    final perms = ref.watch(permsProvider);
    final familyName = ref.watch(familyNameProvider);
    final members = ref.watch(membersProvider(session.familyId)).value ?? const <Member>[];
    final families = ref.watch(familiesProvider).value ?? const <LocalFamily>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                familyName,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (perms.canRenameFamily)
              IconButton(
                tooltip: l.renameFamily,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _rename(context, ref, session.familyId, familyName),
              ),
          ],
        ),
        const _SyncCard(),
        const SyncProblemsCard(),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            icon: const Icon(Icons.troubleshoot, size: 18),
            label: Text(l.syncDiagnostics),
            onPressed: () => showSyncDiagnostics(context),
          ),
        ),
        SectionHeader(
          l.familyMembers,
          count: members.where((m) => !m.removed).length,
          trailing: perms.canInvite
              ? FilledButton.tonalIcon(
                  icon: const Icon(Icons.qr_code_2),
                  label: Text(l.inviteSomeone),
                  onPressed: () => context.push('/invite'),
                )
              : null,
        ),
        Card(
          child: Column(
            children: [
              for (final m in members)
                ListTile(
                  leading: MemberAvatar(m),
                  title: Text(
                    m.id == session.memberId ? '${m.name} (${l.youLabel})' : m.name,
                    style: m.removed ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
                  ),
                  subtitle: Text(m.removed ? l.removedLabel : m.role.label(l)),
                  trailing: perms.canManageMembers && m.id != session.memberId && !m.removed
                      ? PopupMenuButton<String>(
                          onSelected: (v) => _memberAction(context, ref, m, v),
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'role', child: Text(l.changeRole)),
                            PopupMenuItem(value: 'remove', child: Text(l.removeMember)),
                          ],
                        )
                      : m.id == session.memberId
                          ? IconButton(
                              tooltip: l.rename,
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _renameMe(context, ref, m),
                            )
                          : null,
                ),
            ],
          ),
        ),
        const _PhonesSection(),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              if (families.length > 1)
                for (final f in families)
                  RadioListTile<String>(
                    value: f.id,
                    // ignore: deprecated_member_use
                    groupValue: session.familyId,
                    title: Text(f.id == session.familyId ? familyName : f.name),
                    // ignore: deprecated_member_use
                    onChanged: (v) => ref
                        .read(servicesProvider)
                        .settings
                        .set(SettingsStore.kActiveFamily, v),
                  ),
              ListTile(
                leading: const Icon(Icons.group_add_outlined),
                title: Text(l.addAnotherFamily),
                onTap: () => context.push('/welcome'),
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: Text(l.settings),
                onTap: () => context.push('/settings'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _rename(BuildContext context, WidgetRef ref, String familyId, String current) async {
    final name = await _askText(context, context.l10n.renameFamily, context.l10n.familyNameLabel, current);
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(servicesProvider).repo.renameFamily(familyId, name);
    }
  }

  Future<void> _renameMe(BuildContext context, WidgetRef ref, Member me) async {
    final name = await _askText(context, context.l10n.rename, context.l10n.yourNameLabel, me.name);
    if (name != null && name.trim().isNotEmpty) {
      await ref.read(servicesProvider).repo.renameMember(me.familyId, me.id, name);
    }
  }

  Future<void> _memberAction(BuildContext context, WidgetRef ref, Member m, String action) async {
    final l = context.l10n;
    final repo = ref.read(servicesProvider).repo;
    if (action == 'remove') {
      if (await confirm(
        context,
        title: l.removeMember,
        body: l.removeMemberConfirm(m.name),
        action: l.remove,
        destructive: true,
      )) {
        await repo.removeMember(m.familyId, m.id);
      }
      return;
    }
    if (!context.mounted) return;
    final role = await showModalBottomSheet<Role>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in Role.values)
              ListTile(
                title: Text(r.label(l)),
                subtitle: Text(r.description(l)),
                trailing: r == m.role ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, r),
              ),
          ],
        ),
      ),
    );
    if (role != null) await repo.setMemberRole(m.familyId, m.id, role);
  }
}

Future<String?> _askText(BuildContext context, String title, String label, String initial) async {
  final c = TextEditingController(text: initial);
  final l = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.save)),
      ],
    ),
  );
  return ok == true ? c.text : null;
}

class _SyncCard extends ConsumerWidget {
  const _SyncCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider)!;
    final status = ref.watch(syncStatusProvider).value;
    final last = ref.watch(lastSyncProvider(session.familyId)).value;
    final peers = status?.peers ?? const [];
    final syncing = status?.syncing ?? false;

    final String headline;
    if (syncing) {
      headline = l.syncing;
    } else if (last != null) {
      headline = l.syncedWith(last.peerName, timeAgo(context, last.at));
    } else {
      headline = l.syncNever;
    }
    final String detail;
    if (!(status?.running ?? false)) {
      detail = l.syncOff;
    } else if (peers.isEmpty) {
      detail = l.syncSearching;
    } else {
      detail = l.syncPeersNearby(peers.length);
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              syncing
                  ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3))
                  : Icon(Icons.sync, size: 28, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headline, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(detail, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              FilledButton(
                onPressed: syncing
                    ? null
                    : () async {
                        final services = ref.read(servicesProvider);
                        final sync = services.sync;
                        await services.health.refresh();
                        await sync.retryTransports();
                        if (!context.mounted) return;
                        if (sync.current.peers.isEmpty) {
                          showSnack(context, l.syncNoPeersToSync);
                        }
                        await sync.syncAll(force: true);
                      },
                child: Text(l.syncNow),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhonesSection extends ConsumerWidget {
  const _PhonesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final session = ref.watch(sessionProvider)!;
    final known = ref.watch(knownPeersProvider(session.familyId)).value ?? const [];
    final live = {for (final p in ref.watch(syncStatusProvider).value?.peers ?? const []) p.deviceId};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(l.familyPhones, count: known.isEmpty ? null : known.length),
        if (known.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(l.noPhonesYet, style: Theme.of(context).textTheme.bodySmall),
          )
        else
          Card(
            child: Column(
              children: [
                for (final p in known)
                  ListTile(
                    leading: Icon(
                      p.transport == 'nearby' ? Icons.bluetooth : Icons.wifi,
                      color: live.contains(p.deviceId) ? Theme.of(context).colorScheme.primary : null,
                    ),
                    title: Text(p.name),
                    subtitle: Text(
                      p.lastSync == null
                          ? l.phoneSeen(timeAgo(context, DateTime.fromMillisecondsSinceEpoch(p.lastSeen)))
                          : l.phoneLastSynced(
                              timeAgo(context, DateTime.fromMillisecondsSinceEpoch(p.lastSync!)),
                              transportLabel(context, p.transport),
                            ),
                    ),
                    trailing: live.contains(p.deviceId)
                        ? Chip(label: Text(l.nearbyNow), visualDensity: VisualDensity.compact)
                        : null,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
