import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/categories.dart';
import '../../domain/models.dart';
import '../../domain/views.dart';
import '../../ui/format.dart';
import '../../ui/l10n_ext.dart';
import '../../ui/widgets.dart';

/// In-store mode (spec FR-32): items grouped by store section, big targets,
/// one tap to tick off. Works one-handed and offline.
class ShoppingScreen extends ConsumerWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);
    final perms = ref.watch(permsProvider);
    if (session == null) return const Scaffold();
    final entries = ref.watch(entriesProvider(session.familyId)).value ?? const <Entry>[];
    final custom = ref.watch(customCategoriesProvider(session.familyId)).value ?? const [];
    final groups = shoppingGroups(entries);

    return Scaffold(
      appBar: AppBar(title: Text(l.shoppingTitle)),
      body: groups.isEmpty
          ? EmptyState(icon: Icons.celebration_outlined, title: l.shoppingEmpty)
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                Text(l.shoppingHelp, style: theme.textTheme.bodySmall),
                for (final (catId, items) in groups) ...[
                  SectionHeader(
                    categoryById(catId, custom: custom).name(context.locale),
                    count: items.length,
                    color: categoryById(catId, custom: custom).color,
                  ),
                  for (final e in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: CheckboxListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          controlAffinity: ListTileControlAffinity.leading,
                          value: false,
                          title: Text(e.title, style: theme.textTheme.titleMedium),
                          subtitle: e.quantity == null && e.note == null
                              ? null
                              : Text([
                                  if (e.quantity != null) formatQuantity(e.quantity, e.unit),
                                  ?e.note,
                                ].join(' · ')),
                          secondary: e.type == EntryType.outOfStock
                              ? Icon(Icons.inventory_2_outlined, color: theme.colorScheme.error)
                              : null,
                          onChanged: perms.canComplete(e) ? (_) => _bought(context, ref, e) : null,
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  Future<void> _bought(BuildContext context, WidgetRef ref, Entry e) async {
    final services = ref.read(servicesProvider);
    final session = ref.read(sessionProvider);
    if (session == null) return;
    final l = context.l10n;
    await services.repo.setStatus(
      entry: e,
      memberId: session.memberId,
      status: EntryStatus.done,
      activity: 'bought',
    );
    if (!context.mounted) return;
    showSnack(
      context,
      l.shoppingBought(e.title),
      action: SnackBarAction(
        label: l.undo,
        onPressed: () async {
          final latest = await services.store.get(Entities.entry, e.id);
          if (latest == null) return;
          await services.repo.setStatus(
            entry: Entry.fromRecord(latest),
            memberId: session.memberId,
            status: e.status,
          );
        },
      ),
    );
  }
}
