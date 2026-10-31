import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../domain/models.dart';
import '../../ui/format.dart';
import '../../ui/l10n_ext.dart';
import '../../ui/widgets.dart';
import '../scan/bill_review_screen.dart' show addItemsToBoard;
import '../scan/scan_flow.dart';
import 'item_editor.dart';
import 'list_share.dart';

final savedListsProvider = StreamProvider.family<List<SavedList>, String>(
  (ref, familyId) => ref.watch(servicesProvider).repo.watchLists(familyId),
);

final savedListProvider = StreamProvider.family<SavedList?, (String, String)>(
  (ref, k) => ref.watch(servicesProvider).repo.watchList(k.$1, k.$2),
);

final listItemsProvider = StreamProvider.family<List<ListItem>, (String, String)>(
  (ref, k) => ref.watch(servicesProvider).repo.watchListItems(k.$1, k.$2),
);

/// Lists kept for next time: scanned bills and hand-made lists.
class SavedListsScreen extends ConsumerWidget {
  const SavedListsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final session = ref.watch(sessionProvider);
    if (session == null) return const SizedBox.shrink();
    final lists = ref.watch(savedListsProvider(session.familyId)).value;
    final perms = ref.watch(permsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.savedListsTitle),
        actions: [
          if (perms.canAddEntries)
            IconButton(
              tooltip: l.scanBill,
              icon: const Icon(Icons.document_scanner_outlined),
              onPressed: () => startBillScan(context, ref),
            ),
        ],
      ),
      floatingActionButton: perms.canAddEntries
          ? FloatingActionButton.extended(
              heroTag: 'new-list',
              icon: const Icon(Icons.playlist_add),
              label: Text(l.listNew),
              onPressed: () => _newList(context, ref),
            )
          : null,
      body: lists == null
          ? const Center(child: CircularProgressIndicator())
          : lists.isEmpty
          ? EmptyState(
              icon: Icons.receipt_long_outlined,
              title: l.savedListsEmpty,
              body: l.savedListsEmptyBody,
              action: perms.canAddEntries
                  ? FilledButton.icon(
                      icon: const Icon(Icons.document_scanner_outlined),
                      label: Text(l.scanBill),
                      onPressed: () => startBillScan(context, ref),
                    )
                  : null,
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              itemCount: lists.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _ListCard(list: lists[i]),
            ),
    );
  }

  Future<void> _newList(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final session = ref.read(sessionProvider);
    if (session == null) return;
    final c = TextEditingController();
    var kind = ListKind.grocery;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l.listNew),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: c,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l.listName),
              ),
              const SizedBox(height: 16),
              SegmentedButton<ListKind>(
                segments: [
                  ButtonSegment(value: ListKind.grocery, label: Text(l.listKindGrocery)),
                  ButtonSegment(value: ListKind.general, label: Text(l.listKindGeneral)),
                ],
                selected: {kind},
                onSelectionChanged: (s) => setState(() => kind = s.first),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.save)),
          ],
        ),
      ),
    );
    if (ok != true || c.text.trim().isEmpty) return;
    final id = await ref
        .read(servicesProvider)
        .repo
        .createList(familyId: session.familyId, memberId: session.memberId, name: c.text, kind: kind, items: const []);
    if (context.mounted) await context.push('/saved-lists/$id');
  }
}

class _ListCard extends ConsumerWidget {
  const _ListCard({required this.list});
  final SavedList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final items = ref.watch(listItemsProvider((list.familyId, list.id))).value ?? const <ListItem>[];
    final done = items.where((i) => i.checked).length;
    final sub = [
      l.listItemCount(items.length),
      if (done > 0) l.listBoughtCount(done),
      if (list.billTotal != null) formatMoney(list.billTotal!),
    ].join(' · ');
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondaryContainer,
          child: Icon(
            list.fromBill
                ? Icons.receipt_long
                : list.kind == ListKind.grocery
                ? Icons.local_grocery_store
                : Icons.checklist,
            color: theme.colorScheme.onSecondaryContainer,
          ),
        ),
        title: Text(list.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(sub),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/saved-lists/${list.id}'),
      ),
    );
  }
}

/// One saved list: tick items off while shopping (synced to the family),
/// edit lines, share or download, or put the remaining items on the board.
class SavedListScreen extends ConsumerStatefulWidget {
  const SavedListScreen({super.key, required this.listId});
  final String listId;

  @override
  ConsumerState<SavedListScreen> createState() => _SavedListScreenState();
}

class _SavedListScreenState extends ConsumerState<SavedListScreen> {
  final _quick = TextEditingController();
  final _quickFocus = FocusNode();

  @override
  void dispose() {
    _quick.dispose();
    _quickFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final session = ref.watch(sessionProvider);
    if (session == null) return const SizedBox.shrink();
    final key = (session.familyId, widget.listId);
    final listAsync = ref.watch(savedListProvider(key));
    final list = listAsync.value;
    final items = ref.watch(listItemsProvider(key)).value ?? const <ListItem>[];
    final canEdit = ref.watch(permsProvider).canAddEntries;

    if (list == null) {
      return Scaffold(
        appBar: AppBar(),
        body: listAsync.isLoading
            ? const Center(child: CircularProgressIndicator())
            : EmptyState(icon: Icons.search_off, title: l.notFound),
      );
    }
    final repo = ref.read(servicesProvider).repo;
    final showPrices = list.fromBill || items.any((i) => i.amount != null);
    final remaining = items.where((i) => !i.checked).toList();
    final total = items.fold<double>(0, (s, i) => s + (i.amount ?? 0));
    final sub = [
      if (list.store != null) list.store!,
      if (list.billDate != null) formatDate(context, list.billDate!),
      l.listItemCount(items.length),
      if (showPrices && total > 0) formatMoney(total),
    ].join(' · ');

    return Scaffold(
      appBar: AppBar(
        title: Text(list.name),
        actions: [
          IconButton(
            tooltip: l.listShareTitle,
            icon: const Icon(Icons.share_outlined),
            onPressed: items.isEmpty ? null : () => showShareList(context, list, items),
          ),
          if (canEdit)
            PopupMenuButton<String>(
              onSelected: (v) => _menu(v, list, items),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'board', enabled: remaining.isNotEmpty, child: Text(l.listAddRemainingToBoard)),
                PopupMenuItem(value: 'reset', enabled: remaining.length < items.length, child: Text(l.listUntickAll)),
                PopupMenuItem(value: 'rename', child: Text(l.rename)),
                PopupMenuItem(value: 'delete', child: Text(l.delete)),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(sub, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ),
          ),
          if (items.isNotEmpty && remaining.length < items.length)
            LinearProgressIndicator(value: 1 - remaining.length / items.length),
          Expanded(
            child: items.isEmpty
                ? EmptyState(icon: Icons.playlist_add, title: l.listEmpty)
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final it = items[i];
                      final q = formatQuantity(it.quantity, it.unit);
                      final tile = CheckboxListTile(
                        controlAffinity: ListTileControlAffinity.leading,
                        value: it.checked,
                        onChanged: canEdit
                            ? (v) => repo.updateListItem(session.familyId, it, {'checked': v ?? false})
                            : null,
                        title: Text(
                          it.name,
                          style: it.checked
                              ? TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: theme.colorScheme.onSurfaceVariant,
                                )
                              : null,
                        ),
                        subtitle: q.isEmpty ? null : Text(q),
                        secondary: canEdit
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (showPrices && it.amount != null) Text(formatMoney(it.amount!)),
                                  IconButton(
                                    tooltip: l.edit,
                                    icon: const Icon(Icons.edit_outlined, size: 20),
                                    onPressed: () => _edit(session.familyId, it, showPrices),
                                  ),
                                ],
                              )
                            : (showPrices && it.amount != null ? Text(formatMoney(it.amount!)) : null),
                      );
                      if (!canEdit) return tile;
                      return Dismissible(
                        key: ValueKey(it.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: theme.colorScheme.errorContainer,
                          child: Icon(Icons.delete_outline, color: theme.colorScheme.onErrorContainer),
                        ),
                        onDismissed: (_) => repo.deleteListItem(session.familyId, it.id),
                        child: tile,
                      );
                    },
                  ),
          ),
          if (canEdit)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _quick,
                        focusNode: _quickFocus,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(hintText: l.listQuickAddHint, prefixIcon: const Icon(Icons.add)),
                        onSubmitted: (_) => _quickAdd(session.familyId),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send),
                      tooltip: l.add,
                      onPressed: () => _quickAdd(session.familyId),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _quickAdd(String familyId) async {
    final text = _quick.text.trim();
    if (text.isEmpty) return;
    _quick.clear();
    final services = ref.read(servicesProvider);
    await services.repo.addListItem(
      familyId,
      widget.listId,
      text,
      categoryId: services.categorizer.categorize(text).categoryId,
    );
    _quickFocus.requestFocus();
  }

  Future<void> _edit(String familyId, ListItem it, bool showPrices) async {
    final v = await editItemDialog(
      context,
      ItemValues(name: it.name, quantity: it.quantity, unit: it.unit, rate: it.rate, amount: it.amount),
      showPrices: showPrices,
    );
    if (v == null) return;
    await ref.read(servicesProvider).repo.updateListItem(familyId, it, {
      'name': v.name,
      'quantity': v.quantity,
      'unit': v.unit,
      'rate': v.rate,
      'amount': v.amount,
    });
  }

  Future<void> _menu(String action, SavedList list, List<ListItem> items) async {
    final l = context.l10n;
    final session = ref.read(sessionProvider);
    if (session == null) return;
    final repo = ref.read(servicesProvider).repo;
    switch (action) {
      case 'board':
        final n = await addItemsToBoard(repo, session.familyId, session.memberId, [
          for (final i in items.where((i) => !i.checked)) (i.name, i.categoryId, i.quantity, i.unit),
        ]);
        if (mounted) showSnack(context, l.billAddedToBoard(n));
      case 'reset':
        await repo.resetList(session.familyId, list.id);
      case 'rename':
        final c = TextEditingController(text: list.name);
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l.rename),
            content: TextField(controller: c, autofocus: true),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.save)),
            ],
          ),
        );
        if (ok == true && c.text.trim().isNotEmpty) await repo.renameList(session.familyId, list.id, c.text);
      case 'delete':
        if (!await confirm(
          context,
          title: l.listDeleteTitle,
          body: l.listDeleteBody,
          action: l.delete,
          destructive: true,
        )) {
          return;
        }
        await repo.deleteList(session.familyId, list.id);
        if (mounted) context.pop();
    }
  }
}
