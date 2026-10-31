import 'package:flutter/material.dart';

import '../../ui/l10n_ext.dart';

/// The editable parts of a bill or list line.
class ItemValues {
  const ItemValues({required this.name, this.quantity, this.unit, this.rate, this.amount});
  final String name;
  final double? quantity;
  final String? unit;
  final double? rate;
  final double? amount;
}

String _n(double? v) {
  if (v == null) return '';
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  return v.toString();
}

double? _parse(String s) => double.tryParse(s.trim().replaceAll(',', ''));

/// Edits one line. Returns null when cancelled. [showPrices] hides rate and
/// amount for plain to-buy lists.
Future<ItemValues?> editItemDialog(
  BuildContext context,
  ItemValues initial, {
  bool showPrices = true,
  bool isNew = false,
}) {
  final l = context.l10n;
  final name = TextEditingController(text: initial.name);
  final qty = TextEditingController(text: _n(initial.quantity));
  final unit = TextEditingController(text: initial.unit ?? '');
  final rate = TextEditingController(text: _n(initial.rate));
  final amount = TextEditingController(text: _n(initial.amount));
  var amountTouched = initial.amount != null;

  void recompute() {
    if (amountTouched) return;
    final q = _parse(qty.text), r = _parse(rate.text);
    if (q != null && r != null) amount.text = _n(double.parse((q * r).toStringAsFixed(2)));
  }

  qty.addListener(recompute);
  rate.addListener(recompute);

  const numKeys = TextInputType.numberWithOptions(decimal: true);
  return showDialog<ItemValues>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isNew ? l.listAddItem : l.edit),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              autofocus: isNew,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.listItemName),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qty,
                    keyboardType: numKeys,
                    decoration: InputDecoration(labelText: l.quantityLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: unit,
                    decoration: InputDecoration(labelText: l.unitLabel),
                  ),
                ),
              ],
            ),
            if (showPrices) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: rate,
                      keyboardType: numKeys,
                      decoration: InputDecoration(labelText: l.listItemRate),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: amount,
                      keyboardType: numKeys,
                      decoration: InputDecoration(labelText: l.amountLabel),
                      onChanged: (_) => amountTouched = true,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
        FilledButton(
          onPressed: () {
            if (name.text.trim().isEmpty) return;
            final u = unit.text.trim();
            Navigator.pop(
              ctx,
              ItemValues(
                name: name.text.trim(),
                quantity: _parse(qty.text),
                unit: u.isEmpty ? null : u,
                rate: showPrices ? _parse(rate.text) : initial.rate,
                amount: showPrices ? _parse(amount.text) : initial.amount,
              ),
            );
          },
          child: Text(l.save),
        ),
      ],
    ),
  );
}
