import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../app/theme.dart';
import '../../domain/models.dart';
import '../../domain/views.dart';
import '../../ui/l10n_ext.dart';
import '../../ui/widgets.dart';
import '../entries/entry_actions.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final session = ref.watch(sessionProvider);
    if (session == null) return const SizedBox.shrink();
    final entries = ref.watch(entriesProvider(session.familyId));

    return entries.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l.genericError)),
      data: (list) {
        final view = TodayView.build(list, now: DateTime.now(), meId: session.memberId);
        void complete(Entry e) => completeEntry(context, ref, e);
        List<Widget> section(String title, List<Entry> items, {Color? color}) => [
              if (items.isNotEmpty) ...[
                SectionHeader(title, count: items.length, color: color),
                for (final e in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: EntryTile(e, onComplete: () => complete(e)),
                  ),
              ],
            ];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          children: [
            if (view.shoppingCount > 0) _ShoppingCard(count: view.shoppingCount),
            if (view.isEmpty)
              EmptyState(
                icon: Icons.wb_sunny_outlined,
                title: l.todayAllClear,
                body: l.todayAllClearBody,
              ),
            ...section(l.todayOverdue, view.overdue, color: FamTheme.overdue),
            ...section(l.todayDueToday, view.dueToday, color: Theme.of(context).colorScheme.primary),
            ...section(l.todayUrgentRepairs, view.urgentRepairs, color: const Color(0xFFD84315)),
            ...section(l.todayOutOfStock, view.outOfStock),
            ...section(l.todayMine, view.mine),
            ...section(l.todayUpcoming, view.upcoming),
          ],
        );
      },
    );
  }
}

class _ShoppingCard extends StatelessWidget {
  const _ShoppingCard({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        color: theme.colorScheme.secondaryContainer,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/shopping'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.shopping_cart_outlined, color: theme.colorScheme.onSecondaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.shoppingCount(count),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  l.startShopping,
                  style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.onSecondaryContainer),
                ),
                Icon(Icons.chevron_right, color: theme.colorScheme.onSecondaryContainer),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
