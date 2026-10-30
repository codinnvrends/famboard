import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/categories.dart';
import '../../domain/models.dart';
import '../../domain/views.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/l10n_ext.dart';
import '../../ui/widgets.dart';
import '../entries/entry_actions.dart';

class ListsScreen extends ConsumerStatefulWidget {
  const ListsScreen({super.key});

  @override
  ConsumerState<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends ConsumerState<ListsScreen> {
  EntryFilter _filter = const EntryFilter();

  static String _bucketLabel(AppLocalizations l, ListBucket b) => switch (b) {
        ListBucket.allOpen => l.listsAllOpen,
        ListBucket.daily => l.listsDaily,
        ListBucket.weekly => l.listsWeekly,
        ListBucket.monthly => l.listsMonthly,
        ListBucket.yearly => l.listsYearly,
        ListBucket.recurring => l.listsRecurring,
        ListBucket.done => l.listsDone,
        ListBucket.deleted => l.listsDeleted,
      };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = ref.watch(sessionProvider);
    if (session == null) return const SizedBox.shrink();
    final all = ref.watch(allEntriesProvider(session.familyId)).value ?? const <Entry>[];
    final now = DateTime.now();

    return DefaultTabController(
      length: ListBucket.values.length,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [for (final b in ListBucket.values) Tab(text: _bucketLabel(l, b))],
                ),
              ),
              IconButton(
                tooltip: l.filters,
                icon: Badge(
                  isLabelVisible: !_filter.isEmpty,
                  child: const Icon(Icons.filter_list),
                ),
                onPressed: () => _openFilters(context),
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final b in ListBucket.values)
                  _BucketList(
                    entries: (all.where((e) => inBucket(e, b, now) && _filter.matches(e)).toList()
                      ..sort(b == ListBucket.done || b == ListBucket.deleted
                          ? (x, y) => y.updatedAt.compareTo(x.updatedAt)
                          : compareEntries)),
                    deleted: b == ListBucket.deleted,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openFilters(BuildContext context) async {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    final members = ref.read(membersProvider(session.familyId)).value ?? const <Member>[];
    final result = await showModalBottomSheet<EntryFilter>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(initial: _filter, members: members),
    );
    if (result != null) setState(() => _filter = result);
  }
}

class _BucketList extends ConsumerWidget {
  const _BucketList({required this.entries, required this.deleted});

  final List<Entry> entries;
  final bool deleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    if (entries.isEmpty) {
      return EmptyState(icon: Icons.inbox_outlined, title: l.listsEmpty);
    }
    final services = ref.read(servicesProvider);
    final session = ref.read(sessionProvider);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final e = entries[i];
        if (deleted && session != null) {
          return Row(
            children: [
              Expanded(child: EntryTile(e)),
              IconButton(
                tooltip: l.restore,
                icon: const Icon(Icons.restore),
                onPressed: () => services.repo.restoreEntry(e, session.memberId),
              ),
            ],
          );
        }
        return EntryTile(e, onComplete: () => completeEntry(context, ref, e));
      },
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial, required this.members});

  final EntryFilter initial;
  final List<Member> members;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late EntryFilter f = widget.initial;

  Set<T> _toggle<T>(Set<T> s, T v) => s.contains(v) ? ({...s}..remove(v)) : {...s, v};

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(t, style: theme.textTheme.labelLarge),
        );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.filters, style: theme.textTheme.titleLarge),
            label(l.typeLabel),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final t in EntryType.values)
                FilterChip(
                  label: Text(t.label(l)),
                  selected: f.types.contains(t),
                  onSelected: (_) => setState(() => f = f.copyWith(types: _toggle(f.types, t))),
                ),
            ]),
            label(l.categoryLabel),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final c in builtInCategories.where((c) => c.isTop))
                FilterChip(
                  label: Text(c.name(context.locale)),
                  selected: f.topCategories.contains(c.id),
                  onSelected: (_) =>
                      setState(() => f = f.copyWith(topCategories: _toggle(f.topCategories, c.id))),
                ),
            ]),
            label(l.priorityLabel),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final p in Priority.values)
                FilterChip(
                  label: Text(p.label(l)),
                  selected: f.priorities.contains(p),
                  onSelected: (_) => setState(() => f = f.copyWith(priorities: _toggle(f.priorities, p))),
                ),
            ]),
            label(l.assigneeLabel),
            Wrap(spacing: 8, runSpacing: 4, children: [
              FilterChip(
                label: Text(l.nobody),
                selected: f.assignees.contains(''),
                onSelected: (_) => setState(() => f = f.copyWith(assignees: _toggle(f.assignees, ''))),
              ),
              for (final m in widget.members.where((m) => !m.removed))
                FilterChip(
                  avatar: MemberAvatar(m, radius: 10),
                  label: Text(m.name),
                  selected: f.assignees.contains(m.id),
                  onSelected: (_) => setState(() => f = f.copyWith(assignees: _toggle(f.assignees, m.id))),
                ),
            ]),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, const EntryFilter()),
                  child: Text(l.clearFilters),
                ),
                const Spacer(),
                FilledButton(onPressed: () => Navigator.pop(context, f), child: Text(l.save)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
