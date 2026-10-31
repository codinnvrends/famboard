import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/models.dart';

/// Turns a saved list into something to send: plain text for WhatsApp,
/// CSV for a spreadsheet, or a printable PDF.
class ListExport {
  const ListExport();

  static String fileStem(String name, DateTime when) {
    final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
    final day = DateFormat('yyyy-MM-dd').format(when);
    return 'FamBoard-${safe.isEmpty ? 'list' : safe}-$day';
  }

  static String quantityText(ListItem i) {
    final q = i.quantity;
    if (q == null) return i.unit ?? '';
    final n = q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '');
    return i.unit == null ? n : '$n ${i.unit}';
  }

  static String money(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  /// A checklist for chat apps. Items already bought are left out unless
  /// [includeChecked]; prices only when [withPrices].
  String text(SavedList list, List<ListItem> items, {bool withPrices = false, bool includeChecked = true}) {
    final b = StringBuffer();
    final icon = list.kind == ListKind.grocery ? '🛒' : '📝';
    b.writeln('$icon *${list.name}*');
    final shown = includeChecked ? items : items.where((i) => !i.checked).toList();
    for (final i in shown) {
      final q = quantityText(i);
      final price = withPrices && i.amount != null ? '  ₹${money(i.amount!)}' : '';
      b.writeln('${i.checked ? '☑' : '☐'} ${i.name}${q.isEmpty ? '' : ' — $q'}$price');
    }
    if (withPrices) {
      final total = shown.fold<double>(0, (s, i) => s + (i.amount ?? 0));
      if (total > 0) b.writeln('Total ₹${money(total)}');
    }
    b.write('— FamBoard');
    return b.toString();
  }

  String csv(SavedList list, List<ListItem> items) {
    String cell(Object? v) {
      final s = switch (v) {
        null => '',
        final double d => d == d.roundToDouble() ? d.toStringAsFixed(0) : '$d',
        _ => '$v',
      };
      return RegExp(r'[",\n]').hasMatch(s) ? '"${s.replaceAll('"', '""')}"' : s;
    }

    final rows = <List<Object?>>[
      ['Item', 'Quantity', 'Unit', 'Rate', 'Amount', 'Bought'],
      for (final i in items) [i.name, i.quantity, i.unit, i.rate, i.amount, i.checked ? 'yes' : ''],
    ];
    return rows.map((r) => r.map(cell).join(',')).join('\r\n');
  }

  /// [regular] and [bold] are TTF bytes of a font covering Latin, ₹ and
  /// Devanagari (Noto Sans Devanagari is bundled).
  Future<Uint8List> pdf(
    SavedList list,
    List<ListItem> items, {
    required ByteData regular,
    required ByteData bold,
    bool withPrices = true,
  }) async {
    final theme = pw.ThemeData.withFont(base: pw.Font.ttf(regular), bold: pw.Font.ttf(bold));
    final doc = pw.Document(title: list.name, creator: 'FamBoard');
    final hasPrices = withPrices && items.any((i) => i.amount != null);
    final total = items.fold<double>(0, (s, i) => s + (i.amount ?? 0));
    final sub = [
      if (list.store != null) list.store!,
      if (list.billDate != null) DateFormat('d MMM yyyy').format(list.billDate!),
    ].join(' · ');

    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => [
          pw.Text(list.name, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          if (sub.isNotEmpty) pw.Padding(padding: const pw.EdgeInsets.only(top: 4), child: pw.Text(sub)),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['', 'Item', 'Qty', if (hasPrices) 'Amount (₹)'],
            data: [
              for (final i in items)
                [
                  i.checked ? '✓' : '',
                  i.name,
                  quantityText(i),
                  if (hasPrices) i.amount == null ? '' : money(i.amount!),
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignments: {0: pw.Alignment.center, 2: pw.Alignment.centerRight, 3: pw.Alignment.centerRight},
            columnWidths: {
              0: const pw.FixedColumnWidth(22),
              1: const pw.FlexColumnWidth(5),
              2: const pw.FlexColumnWidth(1.4),
              if (hasPrices) 3: const pw.FlexColumnWidth(1.4),
            },
            border: pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          ),
          if (hasPrices)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 12),
              child: pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Total ₹${money(total)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
    return doc.save();
  }
}
