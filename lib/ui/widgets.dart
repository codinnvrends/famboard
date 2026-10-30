import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../app/theme.dart';
import '../domain/categories.dart';
import '../domain/models.dart';
import '../domain/views.dart';
import 'format.dart';
import 'l10n_ext.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.count, this.color, this.trailing});

  final String title;
  final int? count;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color ?? theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.2,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (color ?? theme.colorScheme.primary).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color ?? theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.body, this.action});

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: theme.colorScheme.onSecondaryContainer),
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

const _avatarColors = [
  Color(0xFF1F6F6B), Color(0xFFB4532A), Color(0xFF5E35B1), Color(0xFF1565C0),
  Color(0xFFAD1457), Color(0xFF2E7D32), Color(0xFF6D4C41), Color(0xFFC77C02),
];

class MemberAvatar extends StatelessWidget {
  const MemberAvatar(this.member, {super.key, this.radius = 18});

  final Member member;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final color = _avatarColors[member.color % _avatarColors.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(
        member.initials,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: radius * 0.8),
      ),
    );
  }
}

/// Icon badge for an entry: the category's colour with the type's icon.
class EntryIcon extends StatelessWidget {
  const EntryIcon(this.entry, {super.key, this.custom = const []});

  final Entry entry;
  final List<CustomCategory> custom;

  @override
  Widget build(BuildContext context) {
    final cat = categoryById(entry.categoryId, custom: custom);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: cat.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(cat.icon, color: cat.color, size: 22),
    );
  }
}

/// One entry in any list. [onComplete] shows a one-tap completion button.
class EntryTile extends ConsumerWidget {
  const EntryTile(this.entry, {super.key, this.onComplete, this.showCategory = true});

  final Entry entry;
  final VoidCallback? onComplete;
  final bool showCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final perms = ref.watch(permsProvider);
    final names = ref.watch(memberNamesProvider);
    final session = ref.watch(sessionProvider);
    final custom = session == null
        ? const <CustomCategory>[]
        : ref.watch(customCategoriesProvider(session.familyId)).value ?? const [];

    final days = daysUntilDue(entry, DateTime.now());
    final overdue = entry.isOpen && days != null && days < 0;
    final parts = <String>[
      if (showCategory) categoryName(context, entry.categoryId, custom: custom),
      if (entry.quantity != null) formatQuantity(entry.quantity, entry.unit),
      if (entry.amount != null && perms.canSeeAmounts) formatMoney(entry.amount!),
      if (entry.assigneeId != null && entry.isOpen)
        l.claimedBy(names[entry.assigneeId] ?? l.someone),
    ];
    final due = entry.isOpen ? dueLabel(context, entry) : '';
    final done = entry.status.isClosed;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/entry/${entry.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              EntryIcon(entry, custom: custom),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            entry.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              decoration: done ? TextDecoration.lineThrough : null,
                              color: done ? theme.colorScheme.onSurfaceVariant : null,
                            ),
                          ),
                        ),
                        if (entry.priority.isHighOrAbove && entry.isOpen) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.priority_high,
                            size: 16,
                            color: entry.priority == Priority.urgent
                                ? FamTheme.overdue
                                : theme.colorScheme.secondary,
                          ),
                        ],
                        if (entry.isRecurring) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.repeat, size: 15, color: theme.colorScheme.onSurfaceVariant),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          if (due.isNotEmpty)
                            TextSpan(
                              text: parts.isEmpty ? due : '$due · ',
                              style: TextStyle(
                                color: overdue ? FamTheme.overdue : theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          TextSpan(text: parts.join(' · ')),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (onComplete != null && entry.isOpen && perms.canComplete(entry))
                IconButton(
                  tooltip: entry.type == EntryType.bill
                      ? l.markPaid
                      : entry.type.isShopping
                          ? l.markBought
                          : l.markDone,
                  icon: const Icon(Icons.check_circle_outline),
                  color: theme.colorScheme.primary,
                  onPressed: onComplete,
                )
              else
                const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact sync state for the app bar (spec FR-52): who we last synced
/// with, how long ago, over what; amber when it has been a while.
class SyncBadge extends ConsumerWidget {
  const SyncBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);
    if (session == null) return const SizedBox.shrink();
    final status = ref.watch(syncStatusProvider).value;
    final last = ref.watch(lastSyncProvider(session.familyId)).value;

    final IconData icon;
    final String label;
    Color color = theme.colorScheme.onSurfaceVariant;
    if (status?.syncing ?? false) {
      icon = Icons.sync;
      label = l.syncing;
      color = theme.colorScheme.primary;
    } else if (last != null) {
      final days = DateTime.now().difference(last.at).inDays;
      icon = days >= 2 ? Icons.sync_problem : Icons.cloud_done_outlined;
      label = days >= 2 ? l.syncStale(days) : timeAgo(context, last.at);
      if (days >= 2) color = FamTheme.marigold;
    } else {
      icon = Icons.sync_disabled;
      label = l.syncNever;
    }
    final peers = status?.peers.length ?? 0;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ActionChip(
        avatar: Icon(icon, size: 18, color: color),
        label: Text(peers > 0 ? '$label · $peers' : label),
        labelStyle: theme.textTheme.labelMedium?.copyWith(color: color),
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        visualDensity: VisualDensity.compact,
        onPressed: () => context.go('/family'),
      ),
    );
  }
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? body,
  required String action,
  bool destructive = false,
}) async {
  final l = context.l10n;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showSnack(BuildContext context, String message, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}
