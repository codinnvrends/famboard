import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/categories.dart';
import '../../domain/models.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/format.dart';
import '../../ui/l10n_ext.dart';
import '../../ui/widgets.dart';
import 'entry_actions.dart';
import 'entry_form.dart';

final _entryProvider = StreamProvider.family<Entry?, (String, String)>((ref, key) {
  return ref.watch(servicesProvider).repo.watchEntry(key.$1, key.$2);
});

final _activityProvider = StreamProvider.family<List<Activity>, (String, String)>((ref, key) {
  return ref.watch(servicesProvider).repo.watchActivity(key.$1, key.$2);
});

class EntryDetailScreen extends ConsumerWidget {
  const EntryDetailScreen({super.key, required this.entryId});

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final session = ref.watch(sessionProvider);
    if (session == null) return const Scaffold();
    final key = (session.familyId, entryId);
    final entry = ref.watch(_entryProvider(key));

    return entry.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(), body: Center(child: Text(l.genericError))),
      data: (e) => e == null
          ? Scaffold(appBar: AppBar(), body: EmptyState(icon: Icons.search_off, title: l.notFound))
          : _Detail(entry: e, activity: ref.watch(_activityProvider(key)).value ?? const []),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.entry, required this.activity});

  final Entry entry;
  final List<Activity> activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final services = ref.watch(servicesProvider);
    final session = ref.watch(sessionProvider)!;
    final perms = ref.watch(permsProvider);
    final names = ref.watch(memberNamesProvider);
    final custom = ref.watch(customCategoriesProvider(session.familyId)).value ?? const [];
    final cat = categoryById(entry.categoryId, custom: custom);
    final mine = entry.assigneeId == session.memberId;

    final completeLabel = entry.type == EntryType.bill
        ? l.markPaid
        : entry.type.isShopping
            ? l.markBought
            : l.markDone;

    return Scaffold(
      appBar: AppBar(
        actions: [
          if (!entry.deleted && perms.canEdit(entry))
            IconButton(
              tooltip: l.edit,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showEditEntry(context, entry),
            ),
          if (!entry.deleted && perms.canDelete(entry))
            IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await confirm(
                  context,
                  title: l.deleteConfirmTitle,
                  body: l.deleteConfirmBody,
                  action: l.delete,
                  destructive: true,
                )) {
                  if (!context.mounted) return;
                  await deleteEntryWithUndo(context, ref, entry);
                  if (context.mounted) context.pop();
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Row(
            children: [
              EntryIcon(entry, custom: custom),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.title,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Chip(avatar: Icon(entry.type.icon, size: 18), label: Text(entry.type.label(l))),
              Chip(
                avatar: Icon(cat.icon, size: 18, color: cat.color),
                label: Text(cat.name(context.locale)),
              ),
              Chip(label: Text(entry.status.label(l))),
              if (entry.priority != Priority.normal)
                Chip(
                  label: Text(entry.priority.label(l)),
                  side: entry.priority == Priority.urgent
                      ? const BorderSide(color: FamTheme.overdue)
                      : null,
                ),
              if (entry.deleted)
                Chip(
                  label: Text(l.deletedBadge),
                  backgroundColor: theme.colorScheme.errorContainer,
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (entry.deleted)
            FilledButton.icon(
              icon: const Icon(Icons.restore),
              label: Text(l.restore),
              onPressed: () => services.repo.restoreEntry(entry, session.memberId),
            )
          else
            _actions(context, ref, completeLabel, mine, perms.canComplete(entry), perms.canClaim(entry)),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                if (entry.dueAt != null)
                  _Field(
                    icon: Icons.event_outlined,
                    label: l.dueLabel,
                    value: '${formatDate(context, entry.dueAt!)}'
                        '${entry.isOpen ? ' · ${dueLabel(context, entry)}' : ''}',
                  ),
                if (entry.isRecurring)
                  _Field(icon: Icons.repeat, label: l.repeatLabel, value: describeRule(context, entry.rrule)),
                if (entry.amount != null)
                  _Field(
                    icon: Icons.currency_rupee,
                    label: l.amountLabel,
                    value: perms.canSeeAmounts ? formatMoney(entry.amount!) : l.amountHidden,
                  ),
                if (entry.quantity != null)
                  _Field(
                    icon: Icons.scale_outlined,
                    label: l.quantityLabel,
                    value: formatQuantity(entry.quantity, entry.unit),
                  ),
                _Field(
                  icon: Icons.person_outline,
                  label: l.assigneeLabel,
                  value: entry.assigneeId == null ? l.nobody : names[entry.assigneeId] ?? l.someone,
                ),
                if (entry.leadDays != null && entry.leadDays! > 0)
                  _Field(
                    icon: Icons.notifications_outlined,
                    label: l.reminderLabel,
                    value: l.reminderDaysBefore(entry.leadDays!),
                  ),
                if (entry.note != null)
                  _Field(icon: Icons.notes, label: l.noteLabel, value: entry.note!),
              ],
            ),
          ),
          SectionHeader(l.historyTitle),
          for (final a in activity)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(_activityIcon(a.action), size: 20),
              title: Text(_activityText(context, l, a, names[a.memberId] ?? l.someone)),
              subtitle: Text(timeAgo(context, a.at)),
            ),
        ],
      ),
    );
  }

  Widget _actions(
    BuildContext context,
    WidgetRef ref,
    String completeLabel,
    bool mine,
    bool canComplete,
    bool canClaim,
  ) {
    final l = context.l10n;
    final services = ref.read(servicesProvider);
    final session = ref.read(sessionProvider)!;
    if (entry.status.isClosed) {
      return OutlinedButton.icon(
        icon: const Icon(Icons.replay),
        label: Text(l.reopen),
        onPressed: canComplete
            ? () => services.repo.setStatus(entry: entry, memberId: session.memberId, status: EntryStatus.open)
            : null,
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (canComplete)
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: Text(completeLabel),
            onPressed: () => completeEntry(context, ref, entry),
          ),
        if (canClaim)
          OutlinedButton.icon(
            icon: Icon(mine ? Icons.person_remove_outlined : Icons.front_hand_outlined),
            label: Text(mine ? l.unclaim : l.claim),
            onPressed: () => services.repo.claim(entry, session.memberId, claim: !mine),
          ),
        if (canComplete)
          TextButton(
            onPressed: () => services.repo.setStatus(
              entry: entry,
              memberId: session.memberId,
              status: EntryStatus.cancelled,
            ),
            child: Text(l.cancelEntry),
          ),
      ],
    );
  }

  static IconData _activityIcon(String action) => switch (action) {
        'created' => Icons.add_circle_outline,
        'claimed' => Icons.front_hand_outlined,
        'unclaimed' => Icons.person_remove_outlined,
        'status' => Icons.flag_outlined,
        'bought' => Icons.shopping_cart_checkout,
        'deleted' => Icons.delete_outline,
        'restored' => Icons.restore,
        _ => Icons.edit_outlined,
      };

  static String _activityText(BuildContext context, AppLocalizations l, Activity a, String name) {
    switch (a.action) {
      case 'created':
        return a.detail == 'recurring' ? l.activityCreatedRecurring(name) : l.activityCreated(name);
      case 'claimed':
        return l.activityClaimed(name);
      case 'unclaimed':
        return l.activityUnclaimed(name);
      case 'status':
        final s = EntryStatus.fromCode(a.detail);
        return l.activityStatus(name, s.label(l).toLowerCase());
      case 'bought':
        return l.activityBought(name);
      case 'deleted':
        return l.activityDeleted(name);
      case 'restored':
        return l.activityRestored(name);
      default:
        return l.activityEdited(name);
    }
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(label, style: Theme.of(context).textTheme.labelMedium),
        subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge),
      );
}
