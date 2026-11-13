import 'dart:convert';
import 'dart:io';

import 'package:famboard/services/receipt/bill_merger.dart';
import 'package:famboard/services/receipt/ocr_types.dart';
import 'package:famboard/services/receipt/receipt_parser.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _fixture(String name) =>
    jsonDecode(File('test/fixtures/bills/$name.json').readAsStringSync()) as Map<String, Object?>;

String _norm(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'\bltrs?\b'), 'l').replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Share of ground-truth items found with the right amount and a similar name.
double _recall(List<BillItem> got, List<Object?> expected) {
  var found = 0;
  final used = <BillItem>{};
  for (final e in expected.cast<List<Object?>>()) {
    final amount = (e[2]! as num).toDouble();
    final match = got.where((g) =>
        !used.contains(g) &&
        g.amount != null &&
        (g.amount! - amount).abs() < 0.02 &&
        nameSimilarity(g.name, e[0]! as String) >= 0.45);
    if (match.isNotEmpty) {
      used.add(match.first);
      found++;
    }
  }
  return found / expected.length;
}

void main() {
  final parser = ReceiptParser();
  ParsedBill parse(String name) => parser.parse(OcrPage.fromJson(_fixture(name)));

  group('reads every line of clear bills exactly', () {
    for (final name in [
      'samsuddin_plumbing', 'maatha_bakery', 'varnamm_tailor', 'pph_books',
      'shreeji_appliances', 'newlite_hardware', 'zudio',
    ]) {
      test(name, () {
        final expected = _fixture(name)['expected']! as Map<String, Object?>;
        final bill = parse(name);
        final items = (expected['items']! as List).cast<List<Object?>>();
        expect(bill.items.length, items.length, reason: bill.items.join('\n'));
        for (var i = 0; i < items.length; i++) {
          final got = bill.items[i];
          expect(_norm(got.name), _norm(items[i][0]! as String), reason: 'name of item $i: $got');
          expect(got.quantity, (items[i][1]! as num).toDouble(), reason: 'qty of $got');
          expect(got.amount, closeTo((items[i][2]! as num).toDouble(), 0.01), reason: 'amount of $got');
        }
        if (expected['total'] != null) {
          expect(bill.printedTotal, (expected['total']! as num).toDouble());
          expect(bill.itemsTotal, closeTo(bill.printedTotal!, 0.01), reason: 'items add up to the total');
        }
        expect(bill.date?.toIso8601String().substring(0, 10), expected['date']);
      });
    }
  });

  test('understands the hard bits', () {
    final hw = parse('newlite_hardware');
    expect(hw.store, 'New Lite');
    // Ditto marks (") repeat the unit above.
    expect(hw.items[2].unit, 'gal');
    expect(hw.items[6].unit, 'L');
    // A printed "Total Sales" label on the same row doesn't hide the item.
    expect(hw.items[9].amount, 430);
    // Wrapped line joins the item above; model numbers stay in the name.
    final sh = parse('shreeji_appliances');
    expect(sh.items.first.name, 'Water Purifier (HUL Classic 23 L)');
    expect(sh.items[2].name, 'Electric Iron GC 1903');
    expect(sh.items[3].rate, 209);
    // Two-line item (prices, then "NAME / HSN / taxable").
    expect(parse('zudio').items.single.name, 'Fragrance Perfume Women');
    expect(parse('zudio').store, 'Zudio');
  });

  group('noisy OCR of a long DMart bill', () {
    test('page 1 finds most items with the right amounts', () {
      final bill = parse('dmart_1');
      final expected = (_fixture('dmart_1')['expected']! as Map)['items']! as List;
      final r = _recall(bill.items, expected);
      // ignore: avoid_print
      print('dmart_1 recall ${(r * 100).round()}%');
      expect(r, greaterThanOrEqualTo(0.6));
      expect(bill.store, 'DMart');
      final dal = bill.items.firstWhere((i) => i.name == 'DAL Chana');
      expect(dal.quantity, 3.146);
      expect(dal.unit, 'kg');
      expect(dal.rate, 95);
      final salt = bill.items.firstWhere((i) => i.name.contains('Salt 1 kg'));
      expect(salt.quantity, 4);
      expect(salt.rate, 29);
    });

    test('last page finds most items and the bill total', () {
      final bill = parse('dmart_5');
      final expected = (_fixture('dmart_5')['expected']! as Map)['items']! as List;
      final r = _recall(bill.items, expected);
      // ignore: avoid_print
      print('dmart_5 recall ${(r * 100).round()}% total ${bill.printedTotal}');
      expect(r, greaterThanOrEqualTo(0.45));
      expect(bill.printedItemCount, 16);
      expect(bill.printedTotal, isNot(16), reason: 'item count is not the total');
    });

    test('never turns tax, total or header lines into items', () {
      for (final n in ['dmart_1', 'dmart_2', 'dmart_3', 'dmart_4', 'dmart_5', 'zudio', 'newlite_hardware']) {
        for (final item in parse(n).items) {
          expect(item.name.toLowerCase(), isNot(matches(RegExp(r'cgst|sgst|gstin|total|invoice|cashier|amount due'))),
              reason: '$n: $item');
        }
      }
    });

    test('five overlapping photos merge without repeating the overlap', () {
      final pages = [for (var i = 1; i <= 5; i++) parse('dmart_$i')];
      final merged = const BillMerger().merge(pages);
      final raw = pages.fold<int>(0, (s, p) => s + p.items.length);
      // ignore: avoid_print
      print('pages ${pages.map((p) => p.items.length).toList()} raw $raw merged ${merged.items.length}');
      expect(merged.items.length, lessThan(raw));
      // Items photographed twice (end of page 1, start of page 2) appear once.
      final walnut250 = merged.items.where((i) => i.amount == 349 && i.name.contains('Walnut')).length;
      expect(walnut250, 1);
      expect(merged.store, 'DMart');
    });
  });

  test('merging keeps genuinely repeated rows', () {
    BillItem item(String n, double a) => BillItem(name: n, categoryId: 'groceries', amount: a);
    final a = ParsedBill(items: [item('Maggi Noodles', 56), item('Nissin Geki 80 g', 40), item('Nissin Geki 80 g', 40)]);
    final b = ParsedBill(items: [item('Nissin Geki 80 g', 40), item('Nissin Geki 80 g', 40), item('Knorr Soup', 45)]);
    final merged = const BillMerger().merge([a, b]);
    expect(merged.items.map((i) => i.name), ['Maggi Noodles', 'Nissin Geki 80 g', 'Nissin Geki 80 g', 'Knorr Soup']);
    final c = ParsedBill(items: [item('Tea', 100), item('Nissin Geki 80 g', 40)]);
    final d = ParsedBill(items: [item('Nissin Geki 80 g', 40), item('Nissin Geki 80 g', 40)]);
    expect(const BillMerger().merge([c, d]).items.length, 3);
  });
}
