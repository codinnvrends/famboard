import '../receipt/ocr_types.dart';
import '../receipt/receipt_parser.dart';

/// What OCR could find on a bill or warranty card. Every field is a guess
/// the person checks before saving.
class WarrantyGuess {
  const WarrantyGuess({
    this.name,
    this.brand,
    this.model,
    this.serial,
    this.invoiceNo,
    this.purchaseDate,
    this.store,
    this.price,
    this.warrantyMonths,
    this.extendedMonths,
    this.helpline,
  });

  final String? name;
  final String? brand;
  final String? model;
  final String? serial;
  final String? invoiceNo;
  final DateTime? purchaseDate;
  final String? store;
  final double? price;
  final int? warrantyMonths;

  /// Extended warranty on top of the maker's, if the paper mentions one.
  final int? extendedMonths;
  final String? helpline;

  /// How many fields were found (0 = nothing useful).
  int get found => [
        name, brand, model, serial, invoiceNo, purchaseDate, store, price, warrantyMonths, helpline,
      ].where((v) => v != null).length;
}

/// Pulls appliance and warranty details out of OCR text: brand, model,
/// serial, invoice number and date, price, warranty length and helpline.
class WarrantyParser {
  WarrantyParser({ReceiptParser? receipt}) : _receipt = receipt ?? ReceiptParser();

  final ReceiptParser _receipt;

  /// Brands sold in Indian homes, matched as whole words.
  static const brands = [
    'Samsung', 'LG', 'Sony', 'Whirlpool', 'Godrej', 'Voltas', 'Daikin', 'Bosch', 'IFB', 'Haier',
    'Panasonic', 'Philips', 'Bajaj', 'Havells', 'Crompton', 'Usha', 'Prestige', 'Kent', 'AO Smith',
    'Blue Star', 'Hitachi', 'Lloyd', 'Carrier', 'Apple', 'OnePlus', 'Xiaomi', 'Redmi', 'Mi', 'Realme',
    'Oppo', 'Vivo', 'Motorola', 'Nokia', 'Dell', 'HP', 'Lenovo', 'Asus', 'Acer', 'Canon', 'Epson',
    'Brother', 'Eureka Forbes', 'Aquaguard', 'Livpure', 'Pureit', 'V-Guard', 'Orient', 'Symphony',
    'Morphy Richards', 'Butterfly', 'Pigeon', 'Hindware', 'Faber', 'Elica', 'Sujata', 'Preethi',
    'Maharaja Whiteline', 'TCL', 'Vu', 'Toshiba', 'Onida', 'Videocon', 'Kenstar', 'Racold',
    'Luminous', 'Microtek', 'Exide', 'Amazon Basics', 'Boat', 'JBL', 'Bose', 'Dyson', 'Kelvinator',
    'Electrolux', 'Siemens', 'Black+Decker', 'Inalsa', 'Wonderchef', 'Atomberg', 'Polar', 'Anchor',
    'Syska', 'Wipro', 'Agaro', 'Kaff', 'Glen', 'Sunflame', 'Hawkins', 'Vguard',
  ];

  /// Product words → a readable name for the item.
  static const _products = <String, String>{
    'refrigerator': 'Refrigerator',
    'fridge': 'Refrigerator',
    'washing machine': 'Washing machine',
    'air conditioner': 'Air conditioner',
    'split ac': 'Air conditioner',
    'window ac': 'Air conditioner',
    'inverter ac': 'Air conditioner',
    'television': 'Television',
    'led tv': 'Television',
    'smart tv': 'Television',
    'microwave': 'Microwave oven',
    'otg': 'Oven toaster grill',
    'mixer grinder': 'Mixer grinder',
    'mixer': 'Mixer grinder',
    'water purifier': 'Water purifier',
    'ro purifier': 'Water purifier',
    'geyser': 'Geyser',
    'water heater': 'Geyser',
    'ceiling fan': 'Ceiling fan',
    'chimney': 'Kitchen chimney',
    'dishwasher': 'Dishwasher',
    'vacuum cleaner': 'Vacuum cleaner',
    'air cooler': 'Air cooler',
    'cooler': 'Air cooler',
    'inverter': 'Inverter',
    'battery': 'Inverter battery',
    'laptop': 'Laptop',
    'notebook': 'Laptop',
    'mobile phone': 'Mobile phone',
    'smartphone': 'Mobile phone',
    'tablet': 'Tablet',
    'printer': 'Printer',
    'induction cooktop': 'Induction cooktop',
    'induction': 'Induction cooktop',
    'iron': 'Iron',
    'air purifier': 'Air purifier',
    'stabilizer': 'Voltage stabilizer',
    'stabiliser': 'Voltage stabilizer',
    'hob': 'Gas hob',
    'speaker': 'Speaker',
    'headphones': 'Headphones',
    'earbuds': 'Earbuds',
    'camera': 'Camera',
    'trimmer': 'Trimmer',
    'hair dryer': 'Hair dryer',
  };

  static const _months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
    'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };

  static const _numberWords = {
    'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6, 'seven': 7, 'ten': 10,
    'twelve': 12, 'eighteen': 18, 'twenty four': 24, 'thirty six': 36,
  };

  static final _modelRe = RegExp(
    r'\b(?:model|mdl|model\s*no\.?|model\s*number|model\s*name)\s*[:.#\-]?\s*([A-Z0-9][A-Z0-9\-/.]{2,24})',
    caseSensitive: false,
  );
  static final _serialRe = RegExp(
    r'\b(?:s\s*/\s*n|serial\s*(?:no\.?|number|#)?|sl\.?\s*no\.?|imei\s*(?:no\.?|1)?|esn)\s*[:.#\-]?\s*([A-Z0-9][A-Z0-9\-/]{4,30})',
    caseSensitive: false,
  );
  static final _invoiceRe = RegExp(
    r'\b(?:tax\s*)?(?:invoice|inv|bill|receipt)\s*(?:no\.?|number|#|num)\s*[:.#\-]?\s*([A-Z0-9][A-Z0-9\-/]{2,24})',
    caseSensitive: false,
  );
  static final _labelledDateRe = RegExp(
    r'\b(?:invoice|inv|bill|purchase|sale|dated?)\s*(?:date|dt)?\s*[:.\-]?\s*(\d{1,2}[\-/. ](?:\d{1,2}|[A-Za-z]{3,9})[\-/. ,]+\d{2,4}|\d{4}-\d{2}-\d{2})',
    caseSensitive: false,
  );
  static final _anyDateRe = RegExp(
    r'\b(\d{1,2}[\-/.](?:\d{1,2}|[A-Za-z]{3,9})[\-/.]\d{2,4}|\d{1,2}\s+[A-Za-z]{3,9},?\s+\d{4}|\d{4}-\d{2}-\d{2})\b',
  );
  static final _warrantyRe = RegExp(
    r'(\d{1,2}|one|two|three|four|five|six|seven|ten|twelve|eighteen|twenty four|thirty six)\s*(?:\+\s*\d{1,2}\s*)?(years?|yrs?|months?|mths?|mo)\b[^.\n]{0,30}?warranty'
    r'|warranty\s*(?:period|duration|for)?\s*[:.\-]?\s*(?:of\s*)?(\d{1,2}|one|two|three|five)\s*(years?|yrs?|months?|mths?)',
    caseSensitive: false,
  );
  static final _partOnlyRe = RegExp(
    r'\bon\s+(?:the\s+)?(?:compressor|motor|panel|magnetron|tank|heating element|battery|display)',
    caseSensitive: false,
  );
  static final _extendedRe = RegExp(
    r'extended\s*warranty[^.\n]{0,20}?(\d{1,2}|one|two|three)\s*(years?|yrs?|months?)'
    r'|(\d{1,2}|one|two|three)\s*(years?|yrs?|months?)\s*extended\s*warranty',
    caseSensitive: false,
  );
  static final _totalRe = RegExp(
    r'\b(?:grand\s*total|net\s*(?:amount|payable|total)|total\s*(?:amount|payable|value)|amount\s*(?:payable|paid)|invoice\s*(?:value|total))\s*[:.]?\s*(?:rs\.?|inr|₹)?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );
  /// Toll-free 1800 / 1860 numbers, however the digits are grouped.
  static final _helplineRe = RegExp(r'\b(1(?:800|860)(?:[\s\-]?\d){6,9})\b');

  /// Reads every photo: bills give store, date and price; warranty cards
  /// give period, model and serial. The first page with a value wins, except
  /// the price, which takes the largest total seen.
  WarrantyGuess parse(List<OcrPage> pages) {
    final lines = [for (final p in pages) ...readingLines(p)];
    final text = lines.join('\n');
    final bills = [
      for (final p in pages)
        if (p.fragments.isNotEmpty) _receipt.parse(p),
    ];

    final model = _first(_modelRe, lines, valid: _looksLikeCode);
    final serial = _first(_serialRe, lines, valid: (v) => _looksLikeCode(v) && v.length >= 5);
    final invoice = _first(_invoiceRe, lines, valid: (v) => RegExp(r'\d').hasMatch(v));
    final brand = _brand(text);
    final date = _purchaseDate(lines) ?? bills.map((b) => b.date).whereType<DateTime>().firstOrNull;
    final store = bills.map((b) => b.store).whereType<String>().firstOrNull;
    final price = _price(lines, bills);
    final (warranty, extended) = _warranty(lines);
    final helpline = _helplineRe.firstMatch(text)?.group(1)?.replaceAll(RegExp(r'\s+'), '-');
    final name = _name(text, bills, brand);

    return WarrantyGuess(
      name: name,
      brand: brand,
      model: model,
      serial: serial,
      invoiceNo: invoice,
      purchaseDate: date,
      store: store,
      price: price,
      warrantyMonths: warranty,
      extendedMonths: extended,
      helpline: helpline,
    );
  }

  /// OCR fragments grouped into left-to-right lines, top to bottom.
  static List<String> readingLines(OcrPage page) {
    final frags = [...page.fragments]..sort((a, b) => a.cy.compareTo(b.cy));
    final rows = <List<OcrFragment>>[];
    for (final f in frags) {
      final row = rows.isEmpty ? null : rows.last;
      if (row != null) {
        final ref = row.first;
        final tol = (ref.height < f.height ? ref.height : f.height) * 0.6;
        if ((f.cy - ref.cy).abs() <= tol) {
          row.add(f);
          continue;
        }
      }
      rows.add([f]);
    }
    return [
      for (final r in rows)
        (r..sort((a, b) => a.left.compareTo(b.left))).map((f) => f.text.trim()).join(' ').trim(),
    ].where((l) => l.isNotEmpty).toList();
  }

  static bool _looksLikeCode(String v) =>
      RegExp(r'\d').hasMatch(v) && !RegExp(r'^\d{1,3}$').hasMatch(v) && !_isDate(v);

  static bool _isDate(String v) => RegExp(r'^\d{1,2}[\-/.]\d{1,2}[\-/.]\d{2,4}$').hasMatch(v);

  /// First capture of [re] across lines; a label alone on its line takes
  /// its value from the next line.
  static String? _first(RegExp re, List<String> lines, {required bool Function(String) valid}) {
    for (var i = 0; i < lines.length; i++) {
      for (final m in re.allMatches(lines[i])) {
        final v = _clean(m.group(1)!);
        if (valid(v)) return v;
      }
      if (i + 1 < lines.length) {
        final joined = '${lines[i]} ${lines[i + 1].split(' ').first}';
        final m = re.firstMatch(joined);
        if (m != null && m.start < lines[i].length && m.end > lines[i].length) {
          final v = _clean(m.group(1)!);
          if (valid(v)) return v;
        }
      }
    }
    return null;
  }

  static String _clean(String v) => v.replaceAll(RegExp(r'[.\-/]+$'), '').toUpperCase();

  static String? _brand(String text) {
    final counts = <String, int>{};
    for (final b in brands) {
      final re = RegExp('(?<![A-Za-z])${RegExp.escape(b)}(?![A-Za-z])', caseSensitive: b.length <= 3);
      final n = re.allMatches(text).length;
      if (n > 0) counts[b] = n;
    }
    if (counts.isEmpty) return null;
    // "Mi" alone is too easy to misread; only keep it if nothing better.
    if (counts.length > 1) counts.remove('Mi');
    final best = counts.entries.reduce((a, b) => b.value > a.value || (b.value == a.value && b.key.length > a.key.length) ? b : a);
    return best.key;
  }

  static DateTime? _purchaseDate(List<String> lines) {
    for (final l in lines) {
      final m = _labelledDateRe.firstMatch(l);
      final d = m == null ? null : parseDate(m.group(1)!);
      if (d != null) return d;
    }
    for (final l in lines) {
      if (RegExp(r'expir|valid\s*till|due', caseSensitive: false).hasMatch(l)) continue;
      for (final m in _anyDateRe.allMatches(l)) {
        final d = parseDate(m.group(1)!);
        if (d != null) return d;
      }
    }
    return null;
  }

  /// Day-first dates as printed on Indian bills: 05/11/2026, 5-Nov-26,
  /// 05.11.26, 5 November 2026, 2026-11-05.
  static DateTime? parseDate(String raw) {
    final s = raw.trim().replaceAll(',', ' ');
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
    if (iso != null) return _valid(int.parse(iso[1]!), int.parse(iso[2]!), int.parse(iso[3]!));
    final parts = s.split(RegExp(r'[\-/. ]+')).where((p) => p.isNotEmpty).toList();
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]) ?? _months[parts[1].toLowerCase().substring(0, parts[1].length < 3 ? parts[1].length : 3)];
    var year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    if (year < 100) year += 2000;
    return _valid(year, month, day);
  }

  static DateTime? _valid(int y, int m, int d) {
    if (y < 1990 || y > DateTime.now().year + 1 || m < 1 || m > 12 || d < 1 || d > 31) return null;
    final dt = DateTime(y, m, d);
    return dt.month == m ? dt : null;
  }

  static double? _price(List<String> lines, List<ParsedBill> bills) {
    final seen = <double>[
      ...bills.map((b) => b.printedTotal).whereType<double>(),
    ];
    for (final l in lines) {
      for (final m in _totalRe.allMatches(l)) {
        final v = double.tryParse(m.group(1)!.replaceAll(',', ''));
        if (v != null && v > 0) seen.add(v);
      }
    }
    if (seen.isEmpty) {
      final items = bills.expand((b) => b.items).map((i) => i.amount).whereType<double>();
      if (items.isNotEmpty) return items.reduce((a, b) => a > b ? a : b);
      return null;
    }
    return seen.reduce((a, b) => a > b ? a : b);
  }

  static int? _toMonths(String n, String unit) {
    final count = int.tryParse(n) ?? _numberWords[n.toLowerCase()];
    if (count == null || count == 0) return null;
    final months = unit.toLowerCase().startsWith('y') ? count * 12 : count;
    return months > 0 && months <= 240 ? months : null;
  }

  /// (maker's warranty, extended warranty) in months. Part-only lines such
  /// as "10 years on compressor" don't count as the item's warranty.
  static (int?, int?) _warranty(List<String> lines) {
    int? general, extended;
    // Judge each clause on its own: "1 year warranty, 10 years on compressor".
    final clauses = [for (final l in lines) ...l.split(RegExp(r'[,;|]'))];
    for (final l in clauses) {
      final x = _extendedRe.firstMatch(l);
      if (x != null) {
        extended ??= x.group(1) != null ? _toMonths(x.group(1)!, x.group(2)!) : _toMonths(x.group(3)!, x.group(4)!);
        continue;
      }
      if (_partOnlyRe.hasMatch(l)) continue;
      final m = _warrantyRe.firstMatch(l);
      if (m == null) continue;
      final v = m.group(1) != null ? _toMonths(m.group(1)!, m.group(2)!) : _toMonths(m.group(3)!, m.group(4)!);
      if (v != null) general ??= v;
    }
    return (general, extended);
  }

  /// The product: a known product word near the brand, else the bill's
  /// priciest line, else just the brand.
  static String? _name(String text, List<ParsedBill> bills, String? brand) {
    final lower = text.toLowerCase();
    String? product;
    var at = -1;
    for (final e in _products.entries) {
      final i = RegExp('(?<![a-z])${RegExp.escape(e.key)}(?![a-z])').firstMatch(lower)?.start ?? -1;
      // Longer phrases first win ties ("washing machine" over "machine").
      if (i >= 0 && (at < 0 || i < at)) {
        at = i;
        product = e.value;
      }
    }
    if (product != null) return brand == null ? product : '$brand $product';
    final items = bills.expand((b) => b.items).where((i) => i.amount != null).toList()
      ..sort((a, b) => b.amount!.compareTo(a.amount!));
    if (items.isNotEmpty && items.first.name.trim().length >= 3) return items.first.name.trim();
    return brand;
  }
}
