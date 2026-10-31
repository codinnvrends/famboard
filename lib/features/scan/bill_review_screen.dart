import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../data/famboard_repository.dart';
import '../../domain/categories.dart';
import '../../domain/models.dart';
import '../../services/receipt/receipt_parser.dart';
import '../../ui/format.dart';
import '../../ui/l10n_ext.dart';
import '../../ui/widgets.dart';
import '../lists/item_editor.dart';
import '../lists/list_share.dart';

class _Line {
  _Line(this.item);
  final BillItem item;
  bool include = true;
}

/// Shows what was read from a bill. Every line can be fixed, dropped or
/// added before it is saved as a list or put on the board.
class BillReviewScreen extends ConsumerStatefulWidget {
  const BillReviewScreen({super.key, required this.bill});
  final ParsedBill bill;

  @override
  ConsumerState<BillReviewScreen> createState() => _BillReviewScreenState();
}

class _BillReviewScreenState extends ConsumerState<BillReviewScreen> {
  late final List<_Line> _lines = [for (final i in widget.bill.items) _Line(i)];
  late final _store = TextEditingController(text: widget.bill.store ?? '');
  late final _name = TextEditingController();
  late DateTime? _date = widget.bill.date;
  late ListKind _kind = _guessKind();
  var _nameEdited = false;
  var _busy = false;

  ListKind _guessKind() {
    final items = widget.bill.items;
    if (items.isEmpty) return ListKind.general;
    final everyday = items.where((i) => i.categoryId.startsWith('groceries') || i.categoryId.startsWith('household'));
    return everyday.length * 2 >= items.length ? ListKind.grocery : ListKind.general;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_nameEdited) _name.text = _defaultName();
  }

  String _defaultName() {
    final l = context.l10n;
    final store = _store.text.trim();
    final when = _date == null ? null : formatDate(context, _date!);
    return [store.isEmpty ? l.billUntitled : store, ?when].join(' · ');
  }

  @override
  void dispose() {
    _store.dispose();
    _name.dispose();
    super.dispose();
  }

  List<_Line> get _selected => _lines.where((x) => x.include).toList();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final total = _selected.fold<double>(0, (s, x) => s + (x.item.amount ?? 0));
    final printed = widget.bill.printedTotal;
    final allIncluded = _selected.length == _lines.length;
    final matches = printed != null && allIncluded && (total - printed).abs() < 1.01;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.billReviewTitle),
        actions: [
          IconButton(
            tooltip: l.listShareTitle,
            icon: const Icon(Icons.share_outlined),
            onPressed: _selected.isEmpty ? null : () => showShareList(context, _asList(), _asItems()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _store,
                  decoration: InputDecoration(
                    labelText: l.billStore,
                    prefixIcon: const Icon(Icons.storefront_outlined),
                  ),
                  onChanged: (_) {
                    if (!_nameEdited) setState(() => _name.text = _defaultName());
                  },
                ),
              ),
              const SizedBox(width: 12),
              ActionChip(
                avatar: const Icon(Icons.event_outlined, size: 18),
                label: Text(_date == null ? l.billDate : formatDate(context, _date!)),
                onPressed: _pickDate,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: InputDecoration(labelText: l.listName, prefixIcon: const Icon(Icons.bookmark_outline)),
            onChanged: (_) => _nameEdited = true,
          ),
          const SizedBox(height: 12),
          SegmentedButton<ListKind>(
            segments: [
              ButtonSegment(
                value: ListKind.grocery,
                icon: const Icon(Icons.local_grocery_store_outlined),
                label: Text(l.listKindGrocery),
              ),
              ButtonSegment(value: ListKind.general, icon: const Icon(Icons.checklist), label: Text(l.listKindGeneral)),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
          const SizedBox(height: 16),
          _TotalCard(total: total, printed: printed, matches: matches, partial: !allIncluded),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  l.billReviewHint,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  final all = !allIncluded;
                  for (final x in _lines) {
                    x.include = all;
                  }
                }),
                child: Text(allIncluded ? l.billSelectNone : l.billSelectAll),
              ),
            ],
          ),
          for (var i = 0; i < _lines.length; i++) _lineTile(i),
          const SizedBox(height: 8),
          OutlinedButton.icon(icon: const Icon(Icons.add), label: Text(l.listAddItem), onPressed: _addLine),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.add_task),
                  label: Text(l.billAddToBoard),
                  onPressed: _busy || _selected.isEmpty ? null : _addToBoard,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.bookmark_add_outlined),
                  label: Text(l.billSaveList),
                  onPressed: _busy || _selected.isEmpty ? null : _saveList,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lineTile(int index) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final line = _lines[index];
    final it = line.item;
    final cat = categoryById(it.categoryId);
    final q = formatQuantity(it.quantity, it.unit);
    final details = [
      if (q.isNotEmpty) q,
      if (it.rate != null && it.quantity != null && it.quantity != 1) '@ ${formatMoney(it.rate!)}',
    ].join('  ');
    return Dismissible(
      key: ObjectKey(line),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.errorContainer,
        child: Icon(Icons.delete_outline, color: theme.colorScheme.onErrorContainer),
      ),
      onDismissed: (_) {
        setState(() => _lines.removeAt(index));
        showSnack(
          context,
          l.billLineRemoved,
          action: SnackBarAction(label: l.undo, onPressed: () => setState(() => _lines.insert(index, line))),
        );
      },
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Checkbox(value: line.include, onChanged: (v) => setState(() => line.include = v ?? false)),
        title: Row(
          children: [
            if (it.lowConfidence)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Tooltip(
                  message: l.billCheckThis,
                  child: Icon(Icons.warning_amber_rounded, size: 18, color: theme.colorScheme.tertiary),
                ),
              ),
            Expanded(child: Text(it.name)),
          ],
        ),
        subtitle: Text([cat.name(context.locale), if (details.isNotEmpty) details].join(' · ')),
        trailing: Text(it.amount == null ? '—' : formatMoney(it.amount!), style: theme.textTheme.titleSmall),
        onTap: () => _editLine(line),
      ),
    );
  }

  Future<void> _editLine(_Line line) async {
    final it = line.item;
    final v = await editItemDialog(
      context,
      ItemValues(name: it.name, quantity: it.quantity, unit: it.unit, rate: it.rate, amount: it.amount),
    );
    if (v == null) return;
    final services = ref.read(servicesProvider);
    setState(() {
      if (v.name != it.name) it.categoryId = services.categorizer.categorize(v.name).categoryId;
      it
        ..name = v.name
        ..quantity = v.quantity
        ..unit = v.unit
        ..rate = v.rate
        ..amount = v.amount
        ..lowConfidence = false;
    });
  }

  Future<void> _addLine() async {
    final v = await editItemDialog(context, const ItemValues(name: ''), isNew: true);
    if (v == null) return;
    final services = ref.read(servicesProvider);
    setState(
      () => _lines.add(
        _Line(
          BillItem(
            name: v.name,
            categoryId: services.categorizer.categorize(v.name).categoryId,
            quantity: v.quantity,
            unit: v.unit,
            rate: v.rate,
            amount: v.amount,
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now.add(const Duration(days: 1)),
    );
    if (d == null) return;
    setState(() {
      _date = d;
      if (!_nameEdited) _name.text = _defaultName();
    });
  }

  SavedList _asList() {
    final session = ref.read(sessionProvider);
    final store = _store.text.trim();
    return SavedList(
      id: '',
      familyId: session?.familyId ?? '',
      name: _name.text.trim().isEmpty ? _defaultName() : _name.text.trim(),
      kind: _kind,
      store: store.isEmpty ? null : store,
      billDate: _date,
      billTotal: widget.bill.printedTotal,
      createdAt: DateTime.now(),
      fromBill: true,
    );
  }

  List<ListItem> _asItems() => [
    for (final (i, x) in _selected.indexed)
      ListItem(
        id: '',
        listId: '',
        name: x.item.name,
        categoryId: x.item.categoryId,
        quantity: x.item.quantity,
        unit: x.item.unit,
        rate: x.item.rate,
        amount: x.item.amount,
        position: i.toDouble(),
      ),
  ];

  Future<void> _saveList() async {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    setState(() => _busy = true);
    final list = _asList();
    final id = await ref
        .read(servicesProvider)
        .repo
        .createList(
          familyId: session.familyId,
          memberId: session.memberId,
          name: list.name,
          kind: list.kind,
          items: _asItems(),
          storeName: list.store,
          billDate: list.billDate,
          billTotal: list.billTotal,
          fromBill: true,
        );
    if (!mounted) return;
    showSnack(context, context.l10n.listSavedForNextTime);
    context.pushReplacement('/saved-lists/$id');
  }

  Future<void> _addToBoard() async {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    setState(() => _busy = true);
    final repo = ref.read(servicesProvider).repo;
    final added = await addItemsToBoard(repo, session.familyId, session.memberId, [
      for (final x in _selected) (x.item.name, x.item.categoryId, x.item.quantity, x.item.unit),
    ]);
    if (!mounted) return;
    setState(() => _busy = false);
    showSnack(context, context.l10n.billAddedToBoard(added));
  }
}

/// Adds items as "need to buy" entries, skipping ones already open on the
/// board. Returns how many were added.
Future<int> addItemsToBoard(
  FamBoardRepository repo,
  String familyId,
  String memberId,
  List<(String name, String? categoryId, double? qty, String? unit)> items,
) async {
  final taken = {
    for (final e in await repo.entries(familyId))
      if (e.isOpen) FamBoardRepository.duplicateKey(e.title),
  };
  var added = 0;
  for (final (name, categoryId, qty, unit) in items) {
    final key = FamBoardRepository.duplicateKey(name);
    if (key.isNotEmpty && !taken.add(key)) continue;
    // Bill weights (1.342 kg) aren't what you'd ask for next time; counts are.
    final count = qty != null && qty == qty.roundToDouble() && qty > 1;
    await repo.addEntry(
      familyId: familyId,
      memberId: memberId,
      draft: EntryDraft(
        title: name,
        type: EntryType.needToBuy,
        categoryId: categoryId ?? 'groceries',
        quantity: count ? qty : null,
        unit: count ? unit : null,
      ),
    );
    added++;
  }
  return added;
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.total, required this.printed, required this.matches, required this.partial});
  final double total;
  final double? printed;
  final bool matches;
  final bool partial;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final (IconData icon, Color bg, Color fg, String text) = switch ((printed, matches, partial)) {
      (null, _, _) => (
        Icons.calculate_outlined,
        scheme.surfaceContainerHighest,
        scheme.onSurface,
        l.billItemsTotal(formatMoney(total)),
      ),
      (_, true, _) => (
        Icons.check_circle_outline,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
        l.billTotalMatches(formatMoney(printed!)),
      ),
      (_, _, true) => (
        Icons.calculate_outlined,
        scheme.surfaceContainerHighest,
        scheme.onSurface,
        l.billSelectedTotal(formatMoney(total), formatMoney(printed!)),
      ),
      _ => (
        Icons.info_outline,
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        l.billTotalMismatch(formatMoney(total), formatMoney(printed!)),
      ),
    };
    return Card(
      color: bg,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, color: fg),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: TextStyle(color: fg)),
            ),
          ],
        ),
      ),
    );
  }
}
