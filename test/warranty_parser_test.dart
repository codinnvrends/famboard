import 'package:famboard/services/receipt/ocr_types.dart';
import 'package:famboard/services/warranty/warranty_parser.dart';
import 'package:flutter_test/flutter_test.dart';

/// One OCR fragment per line, stacked top to bottom.
OcrPage _page(List<String> lines) => OcrPage([
      for (final (i, l) in lines.indexed) OcrFragment(l, 20, 40.0 * i, 20 + l.length * 12.0, 40.0 * i + 24),
    ], width: 800, height: 40.0 * lines.length);

void main() {
  final parser = WarrantyParser();

  test('reads a typical electronics store tax invoice', () {
    final g = parser.parse([
      _page([
        'CROMA',
        'Infiniti Retail Ltd, Andheri West, Mumbai',
        'TAX INVOICE',
        'Invoice No: CRM/2026/004512',
        'Invoice Date: 05/11/2026',
        'Item Qty Rate Amount',
        'Samsung 253L Double Door Refrigerator 1 27990.00 27990.00',
        'Model No: RT28C3053S8',
        'Serial No: 0A4X7BCT200315',
        'Grand Total Rs. 27,990.00',
        '1 Year comprehensive warranty, 10 years on compressor',
        'Customer care: 1800-40-7267864',
      ]),
    ]);
    expect(g.brand, 'Samsung');
    expect(g.name, 'Samsung Refrigerator');
    expect(g.model, 'RT28C3053S8');
    expect(g.serial, '0A4X7BCT200315');
    expect(g.invoiceNo, 'CRM/2026/004512');
    expect(g.purchaseDate, DateTime(2026, 11, 5));
    expect(g.price, 27990);
    expect(g.warrantyMonths, 12);
    expect(g.helpline, '1800-40-7267864');
  });

  test('reads a warranty card and an extended warranty, across two photos', () {
    final g = parser.parse([
      _page([
        'LG Electronics India Pvt Ltd',
        'WARRANTY CARD',
        'Product: Split Air Conditioner',
        'Model',
        'PS-Q19YNZE',
        'S/N 312KAXX4B556',
        'Date of purchase: 12-Mar-25',
        'Warranty period: 2 years',
      ]),
      _page([
        'OneAssist',
        'Extended Warranty for 3 years',
        'Plan value 2,499',
      ]),
    ]);
    expect(g.brand, 'LG');
    expect(g.name, 'LG Air conditioner');
    expect(g.model, 'PS-Q19YNZE');
    expect(g.serial, '312KAXX4B556');
    expect(g.purchaseDate, DateTime(2025, 3, 12));
    expect(g.warrantyMonths, 24);
    expect(g.extendedMonths, 36);
  });

  test('part-only warranties are not the product warranty', () {
    final g = parser.parse([
      _page([
        'Whirlpool washing machine',
        '10 years warranty on motor',
        '2 years warranty',
      ]),
    ]);
    expect(g.warrantyMonths, 24);
    expect(g.name, 'Whirlpool Washing machine');
  });

  test('a table row number is not a serial number, and expiry dates are not purchase dates', () {
    final g = parser.parse([
      _page([
        'Sr. No 1',
        'Valid till 31/12/2027',
        'Bill date 14.08.2026',
      ]),
    ]);
    expect(g.serial, isNull);
    expect(g.purchaseDate, DateTime(2026, 8, 14));
  });

  test('day-first dates in the usual Indian formats', () {
    expect(WarrantyParser.parseDate('05/11/2026'), DateTime(2026, 11, 5));
    expect(WarrantyParser.parseDate('5-Nov-26'), DateTime(2026, 11, 5));
    expect(WarrantyParser.parseDate('05.11.26'), DateTime(2026, 11, 5));
    expect(WarrantyParser.parseDate('5 November 2026'), DateTime(2026, 11, 5));
    expect(WarrantyParser.parseDate('2026-11-05'), DateTime(2026, 11, 5));
    expect(WarrantyParser.parseDate('31/02/2026'), isNull);
    expect(WarrantyParser.parseDate('12/13/2026'), isNull);
  });

  test('nothing readable gives an empty guess', () {
    expect(parser.parse([_page(['@@@', '---'])]).found, 0);
    expect(parser.parse(const []).found, 0);
  });

  test('fragments on one row are joined left to right', () {
    final page = OcrPage(const [
      OcrFragment('Model', 20, 100, 80, 120),
      OcrFragment('No:', 90, 101, 120, 121),
      OcrFragment('AB-123', 130, 99, 200, 119),
      OcrFragment('Next line', 20, 140, 120, 160),
    ]);
    expect(WarrantyParser.readingLines(page), ['Model No: AB-123', 'Next line']);
  });
}
