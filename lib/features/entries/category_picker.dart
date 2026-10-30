import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/categories.dart';
import '../../domain/models.dart';
import '../../ui/l10n_ext.dart';

/// Bottom sheet listing categories grouped under their top level. Returns the
/// chosen category id.
Future<String?> pickCategory(BuildContext context, {String? current}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CategoryPicker(current: current),
  );
}

class _CategoryPicker extends ConsumerWidget {
  const _CategoryPicker({this.current});
  final String? current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final session = ref.watch(sessionProvider);
    final perms = ref.watch(permsProvider);
    final custom = session == null
        ? const <CustomCategory>[]
        : ref.watch(customCategoriesProvider(session.familyId)).value ?? const [];
    final tops = builtInCategories.where((c) => c.isTop).toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Row(
            children: [
              Text(l.categoryLabel, style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              if (perms.canEditCategories && session != null)
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: Text(l.categoryAdd),
                  onPressed: () async {
                    final id = await _addCategory(context, ref, session.familyId);
                    if (id != null && context.mounted) Navigator.pop(context, id);
                  },
                ),
            ],
          ),
          for (final top in tops) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(top.icon, size: 18, color: top.color),
                const SizedBox(width: 8),
                Text(
                  top.name(context.locale),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in [
                  top,
                  ...builtInCategories.where((c) => !c.isTop && c.parentId == top.id),
                ])
                  ChoiceChip(
                    label: Text(c.isTop ? l.filterAll : c.name(context.locale)),
                    selected: current == c.id,
                    onSelected: (_) => Navigator.pop(context, c.id),
                  ),
                for (final c in custom.where((c) => c.parentId == top.id))
                  ChoiceChip(
                    label: Text(c.name),
                    selected: current == c.id,
                    onSelected: (_) => Navigator.pop(context, c.id),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<String?> _addCategory(BuildContext context, WidgetRef ref, String familyId) async {
    final l = context.l10n;
    final name = TextEditingController();
    var parent = 'groceries';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l.categoryAdd),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                decoration: InputDecoration(labelText: l.categoryNameLabel),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: parent,
                decoration: InputDecoration(labelText: l.categoryParentLabel),
                items: [
                  for (final c in builtInCategories.where((c) => c.isTop))
                    DropdownMenuItem(value: c.id, child: Text(c.name(context.locale))),
                ],
                onChanged: (v) => setState(() => parent = v ?? parent),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.add)),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return null;
    return ref.read(servicesProvider).repo.addCustomCategory(familyId, name.text, parent);
  }
}
