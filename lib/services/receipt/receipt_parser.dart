import 'dart:math';

import '../../core/text.dart';
import '../categorizer/categorizer.dart';
import 'name_cleaner.dart';
import 'ocr_types.dart';

/// One line item read from a bill. Everything is editable in the review
/// screen; [lowConfidence] marks lines worth a second look.
class BillItem {
  BillItem({
    required this.name,
    required this.categoryId,
    this.quantity,
    this.unit,
    this.rate,
    this.amount,
    this.lowConfidence = false,
    this.raw = '',
  });

  String name;
  String categoryId;
  double? quantity;
  String? unit;
  double? rate;
  double? amount;
  bool lowConfidence;

  /// The OCR text the item came from, for debugging and the review screen.
  final String raw;

  @override
  String toString() => 'BillItem($name, q=$quantity $unit, r=$rate, a=$amount${lowConfidence ? ', ?' : ''})';
}

/// What was read from a bill.
class ParsedBill {
  ParsedBill({required this.items, this.store, this.date, this.printedTotal, this.printedItemCount});

  final List<BillItem> items;
  final String? store;
  final DateTime? date;

  /// The bill's own total, used to check the reading.
  final double? printedTotal;
  final int? printedItemCount;

  double get itemsTotal => items.fold(0, (s, i) => s + (i.amount ?? 0));
}

/// A word with its estimated horizontal position.
class _Word {
  _Word(this.text, this.x, this.fragment);
  final String text;
  final double x;
  final int fragment;
}

class _Row {
  _Row(this.y);
  double y;
  final List<OcrFragment> fragments = [];
  double get top => fragments.map((f) => f.top).reduce(min);
  double get bottom => fragments.map((f) => f.bottom).reduce(max);
  String get text => (fragments.toList()..sort((a, b) => a.left.compareTo(b.left))).map((f) => f.text).join('  ');
}

enum _Role { serial, name, qty, unit, rate, amount, ignore }

class _Num {
  const _Num(this.value, {this.decimals = 0, this.money = false});
  final double value;
  final int decimals;

  /// Written like an amount: "50.00", "600-", "75/-".
  final bool money;
}

/// Reads line items from OCR output of Indian shop bills: supermarket
/// thermal receipts (DMart, Zudio…), printed forms and handwritten bills.
class ReceiptParser {
  ReceiptParser({Categorizer? categorizer, this.cleaner = const ItemNameCleaner()})
      : categorizer = categorizer ?? Categorizer();

  final Categorizer categorizer;
  final ItemNameCleaner cleaner;

  // Labels that mark summary, tax and payment lines.
  static final _summary = RegExp(
    r'(sub\s*total|\btotal|grand|net\s*amount|net\s*of\b|amount\s*due|amt\s*due|\bbalance\b|round\s*off|roundoff|'
    r'discount|\bless\s*:|\badd\s*:|\bvat\b|vat-?able|\bgst\b|cgst|sgst|igst|\bcess\b|taxable|\btax\b|payable|'
    r'\bpaid\b|\bcash\b|\bchange\b|tender|paytm|\bupi\b|\bcard\s*no|items\s*:|qty\s*:|no\.?\s*of\s*items|'
    r'saving|you\s*saved|rupees|in\s*words?|e\s*\.?\s*&\s*o\.?\s*e|zero\s*rated|exempt|\bsales\b|\binr\b)',
    caseSensitive: false,
  );

  // A summary label that ends the list of items.
  static final _terminal = RegExp(
    r'(\btotal\b|grand|net\s*amount|amount\s*due|amt\s*due|items\s*:|no\.?\s*of\s*items)',
    caseSensitive: false,
  );

  // Shop details, headers and footers.
  static final _meta = RegExp(
    r'(invoice|bill\s*no|bill\s*dt|\bvou\b|gstin|\bcin\b|fssai|phone|\bph\b|mob(ile)?\b|cashier|counter|customer|'
    r'cust\s*id|walk-?\s*in|\bm/s\b|messrs|sold\s*to|address|received|signature|signatory|thank|visit|terms|'
    r'goods\s*once|will\s*not\s*be|subject\s*to|pan\s*no|\btin\b|\bdate\b|dated|order\s*no|specialist|'
    r'store\s*address|regd|registered|www\.|e-?mail|@|cash\s*memo|lunch\s*time|delivery\s*time|holiday|'
    r'pvt|ltd\b|limited|enterprises|agencies|road\b|nagar\b|zone\b|maharashtra|delhi|mumbai)',
    caseSensitive: false,
  );

  static const Map<_Role, List<String>> _headerLabels = {
    _Role.serial: ['sr', 'sr.', 'sno', 's.no', 's.no.', 'sl', 'no.', 'no', '#'],
    _Role.name: ['particulars', 'description', 'item', 'items', 'articles', 'article', 'details', 'goods', 'product'],
    _Role.qty: ['qty', 'qty.', 'quantity', 'qty/kg', 'qty/unit', 'pcs', 'pcs.'],
    _Role.unit: ['unit', 'size', 'uom'],
    _Role.rate: ['rate', 'price', 'n/rate', 'mrp', 'unit price'],
    _Role.amount: ['amount', 'value', 'amt', 'netamt', 'net amt', 'rs.', 'rs', 'total'],
    _Role.ignore: ['hsn', 'disc', 'disc.amt', 'discount', 'p.', 'p', 'tax', 'gst'],
  };

  static const Set<String> _units = {
    'pc', 'pcs', 'piece', 'pieces', 'nos', 'no', 'set', 'sets', 'kg', 'kgs', 'kilo', 'kilos', 'g', 'gm', 'gms',
    'ltr', 'liter', 'litre', 'lt', 'l', 'ml', 'm', 'mtr', 'mtrs', 'meter', 'gal', 'gals', 'yd', 'yds', 'dozen',
    'dz', 'pkt', 'pkts', 'box', 'bag', 'roll', 'pair', 'bottle',
  };

  static final _notStore = RegExp(
    r'(phone|\bph\b|mob|gstin|\bcin\b|fssai|invoice|memo|bill|date|road|nagar|zone|street|address|'
    r'\bno\.|e-?mail|www|specialist|pan\b|tin\b|m/s|messrs|name\s*:)',
    caseSensitive: false,
  );

  static const Map<String, String> _chains = {
    'dmart': 'DMart', 'd mart': 'DMart', 'omart': 'DMart', '0mart': 'DMart', 'supermarts': 'DMart',
    'avenue': 'DMart', 'kachimeth': 'DMart', 'zudio': 'Zudio', 'trent': 'Zudio',
    'reliance smart': 'Reliance Smart', 'reliance fresh': 'Reliance Fresh', 'big bazaar': 'Big Bazaar',
    'more retail': 'More', 'spencer': "Spencer's", 'star bazaar': 'Star Bazaar', 'westside': 'Westside',
    'nature': "Nature's Basket", 'vishal mega': 'Vishal Mega Mart', 'ratnadeep': 'Ratnadeep',
  };

  ParsedBill parse(OcrPage page) {
    final frags = page.fragments.where((f) => f.text.trim().isNotEmpty && f.height > 0).toList();
    if (frags.isEmpty) return ParsedBill(items: []);
    final h = _median(frags.map((f) => f.height).toList());
    final rows = _buildRows(frags, h);

    final header = _findHeader(rows);
    final columns = header?.$2;
    final items = <BillItem>[];
    final itemRowBottoms = <double>[];
    double? printedTotal;
    int? printedCount;
    var ended = false;
    _PendingNumbers? pending;
    String? lastUnit;

    _firstItemTop = null;
    for (var i = header == null ? 0 : header.$1 + 1; i < rows.length; i++) {
      final row = rows[i];
      final words = _words(row);
      if (words.isEmpty) continue;

      // Remove summary/meta label fragments; note whether the row ends items.
      final labelFrags = <int>{};
      var terminal = false;
      for (var f = 0; f < row.fragments.length; f++) {
        final t = row.fragments[f].text;
        final isSummary = _summary.hasMatch(t);
        if (isSummary || _meta.hasMatch(t)) {
          labelFrags.add(f);
          if (isSummary && _terminal.hasMatch(t)) terminal = true;
        }
      }
      final rest = words.where((w) => !labelFrags.contains(w.fragment)).toList();
      final hasName = rest.any((w) => _isNameWord(w.text));

      if (terminal && !hasName) {
        final count = RegExp(r'items\s*:?\s*(\d+)', caseSensitive: false).firstMatch(row.text);
        if (count != null) printedCount = int.tryParse(count.group(1)!);
        // "Items: 16" is a count, not money.
        final money = count == null ? rest : rest.where((w) => w.text != count.group(1)).toList();
        final n = _lastMoney(money);
        if (n != null && (printedTotal == null || n > printedTotal)) printedTotal = n;
        if (items.isNotEmpty) ended = true;
        pending = null;
        continue;
      }
      if (ended || rest.isEmpty) continue;
      if (labelFrags.isNotEmpty && !hasName) {
        pending = null;
        continue;
      }

      final parsed = columns != null ? _parseWithColumns(rest, columns) : _parseFree(rest);
      if (parsed == null) continue;

      // Unit ditto marks (") mean "same as above".
      if (parsed.dittoUnit) parsed.unit = lastUnit;
      if (parsed.unit != null) lastUnit = parsed.unit;

      final nameText = parsed.name.trim();
      var hasNumbers = parsed.amount != null || parsed.rate != null;
      // "NAME / HSN / taxable value" under a line of prices (Zudio).
      if (pending != null && row.top - pending.bottom < 2.2 * h && row.text.contains('/') && _hasLetters(nameText, 3)) {
        hasNumbers = false;
      }

      if (nameText.isEmpty || !_hasLetters(nameText, 2)) {
        // Numbers without a name: maybe a two-line item (name follows).
        pending = hasNumbers ? _PendingNumbers(parsed, row.bottom) : null;
        continue;
      }

      if (!hasNumbers) {
        final gap = items.isEmpty ? double.infinity : row.top - itemRowBottoms.last;
        if (pending != null && row.top - pending.bottom < 2.2 * h) {
          // Zudio style: code + prices, then "NAME / HSN / taxable".
          final name = row.text.split(RegExp(r'\s+/\s+|\s/|/\s')).first;
          items.add(_finish(pending.parsed..name = name, row.text));
          itemRowBottoms.add(row.bottom);
          pending = null;
          continue;
        }
        if (parsed.startsWithCode) {
          // A coded item whose prices weren't read (faded print).
          items.add(_finish(parsed, row.text)..lowConfidence = true);
          itemRowBottoms.add(row.bottom);
          continue;
        }
        if (!parsed.startsWithSerial && items.isNotEmpty && gap < 1.9 * h) {
          // Wrapped name, e.g. "(HUL classic 23 Ltr)" under "Water Purifier".
          final prev = items.last;
          prev.name = cleaner.clean('${_rawName(prev)} $nameText');
          prev.categoryId = categorizer.categorize(prev.name).categoryId;
          itemRowBottoms[itemRowBottoms.length - 1] = row.bottom;
        }
        continue;
      }
      pending = null;
      _firstItemTop ??= row.top;
      items.add(_finish(parsed, row.text));
      itemRowBottoms.add(row.bottom);
    }

    return ParsedBill(
      items: items,
      store: _store(rows, items.isEmpty ? double.infinity : _firstItemTop ?? double.infinity),
      date: _date(rows),
      printedTotal: printedTotal,
      printedItemCount: printedCount,
    );
  }

  double? _firstItemTop;

  /// Uncleaned names, so a wrapped second line joins the original text.
  final _rawNames = Expando<String>();
  String _rawName(BillItem item) => _rawNames[item] ?? item.name;

  BillItem _finish(_ParsedRow p, String raw) {
    final name = cleaner.clean(p.name);
    final item = BillItem(
      name: name,
      categoryId: categorizer.categorize(name).categoryId,
      quantity: p.qty,
      unit: p.unit,
      rate: p.rate,
      amount: p.amount,
      lowConfidence: p.lowConfidence,
      raw: raw,
    );
    _rawNames[item] = p.name;
    return item;
  }

  // ---------------------------------------------------------------- rows

  List<_Row> _buildRows(List<OcrFragment> frags, double h) {
    // Photos are rarely level. Try small slopes and keep the one where
    // fragments line up into the sharpest rows (a projection profile).
    var slope = 0.0;
    var bestScore = -1.0;
    final sortedX = frags.map((f) => f.cx).toList();
    for (var k = -60; k <= 60; k++) {
      final sTry = k * 0.002;
      final ys = [for (var i = 0; i < frags.length; i++) frags[i].cy - sTry * sortedX[i]]..sort();
      var score = 0.0;
      var j = 0;
      for (var i = 0; i < ys.length; i++) {
        while (ys[i] - ys[j] > 0.22 * h) {
          j++;
        }
        score += i - j;
      }
      // Prefer level when scores tie.
      score -= k.abs() * 0.01;
      if (score > bestScore) {
        bestScore = score;
        slope = sTry;
      }
    }
    double yOf(OcrFragment f) => f.cy - slope * f.cx;

    final sorted = frags.toList()..sort((a, b) => yOf(a).compareTo(yOf(b)));
    final rows = <_Row>[];
    for (final f in sorted) {
      final y = yOf(f);
      _Row? target;
      for (var r = rows.length - 1; r >= 0 && r >= rows.length - 3; r--) {
        final row = rows[r];
        if ((row.y - y).abs() > 0.55 * h) continue;
        final overlaps = row.fragments.any((g) {
          final ov = min(g.right, f.right) - max(g.left, f.left);
          return ov > 0.3 * min(g.width, f.width);
        });
        if (!overlaps) {
          target = row;
          break;
        }
      }
      if (target == null) {
        target = _Row(y);
        rows.add(target);
      } else {
        target.y = (target.y * target.fragments.length + y) / (target.fragments.length + 1);
      }
      target.fragments.add(f);
    }
    for (final r in rows) {
      r.fragments.sort((a, b) => a.left.compareTo(b.left));
    }
    rows.sort((a, b) => a.y.compareTo(b.y));
    return rows;
  }

  List<_Word> _words(_Row row) {
    final out = <_Word>[];
    for (var f = 0; f < row.fragments.length; f++) {
      final frag = row.fragments[f];
      // OCR glues "4-35.00" (qty, rate); split dashes between numbers.
      final text = frag.text.replaceAllMapped(RegExp(r'(\d)-(\d)'), (m) => '${m[1]} ${m[2]}');
      final total = max(1, text.length);
      var offset = 0;
      for (final m in RegExp(r'\S+').allMatches(text)) {
        final mid = (m.start + m.end) / 2;
        out.add(_Word(m.group(0)!, frag.left + frag.width * mid / total, f));
        offset = m.end;
      }
      if (offset == 0 && text.trim().isNotEmpty) out.add(_Word(text.trim(), frag.cx, f));
    }
    return out;
  }

  // -------------------------------------------------------------- header

  (int, Map<_Role, double>)? _findHeader(List<_Row> rows) {
    for (var i = 0; i < rows.length; i++) {
      final cols = <_Role, double>{};
      final words = _words(rows[i]);
      for (var w = 0; w < words.length; w++) {
        final lower = words[w].text.toLowerCase().replaceAll(RegExp(r'[:]'), '');
        final next = w + 1 < words.length ? words[w + 1].text.toLowerCase() : '';
        if (lower == 'unit' && next.startsWith('price')) {
          cols[_Role.rate] = (words[w].x + words[w + 1].x) / 2;
          w++;
          continue;
        }
        if (lower == 'net' && next.startsWith('amt')) {
          cols[_Role.amount] = (words[w].x + words[w + 1].x) / 2;
          w++;
          continue;
        }
        for (final e in _headerLabels.entries) {
          if (e.value.contains(lower) || (e.key == _Role.qty && lower.startsWith('qty'))) {
            // First label wins for a role (e.g. "AMOUNT Rs." keeps AMOUNT).
            cols.putIfAbsent(e.key, () => words[w].x);
            break;
          }
        }
      }
      final core = [_Role.name, _Role.qty, _Role.rate, _Role.amount].where(cols.containsKey).length;
      if (core >= 2 && (cols.containsKey(_Role.amount) || cols.containsKey(_Role.rate))) {
        return (i, cols);
      }
    }
    return null;
  }

  // --------------------------------------------------------------- parse

  _ParsedRow? _parseWithColumns(List<_Word> words, Map<_Role, double> cols) {
    _Role nearest(double x, {bool numeric = false}) {
      _Role? best;
      var bestD = double.infinity;
      cols.forEach((role, cx) {
        if (numeric && (role == _Role.name || role == _Role.ignore)) return;
        final d = (cx - x).abs();
        if (d < bestD) {
          bestD = d;
          best = role;
        }
      });
      return best ?? _Role.name;
    }

    final p = _ParsedRow();
    var tokens = words.toList();
    tokens = _stripLeading(tokens, p, (w) => w.text, (w, t) => _Word(t, w.x, w.fragment));
    final lastLetter = tokens.lastIndexWhere((w) => _hasLetters(w.text, 1) && _parseNum(w.text) == null);

    final nameWords = <String>[];
    final nums = <(_Role, _Num, double)>[];
    final unitWords = <String>[];
    for (var i = 0; i < tokens.length; i++) {
      final w = tokens[i];
      final t = w.text;
      var role = nearest(w.x);
      final n = _parseNum(t);
      if (i == 0 && _isSerial(t) && role == _Role.serial) {
        p.startsWithSerial = true;
        continue;
      }
      if (_isDitto(t) && role != _Role.name) {
        p.dittoUnit = true;
        continue;
      }
      if (RegExp(r'^[-—=~_|]+$').hasMatch(t)) continue;
      if (n != null && !_hasLetters(t, 1)) {
        if (role == _Role.serial && nameWords.isEmpty) continue;
        // A decimal number after the name that the OCR glued to it
        // ("KABULI CHANA 1.342") belongs to a number column.
        if (role == _Role.name && i > lastLetter && lastLetter >= 0 && n.decimals > 0) {
          role = nearest(w.x, numeric: true);
        }
        if (role != _Role.name && role != _Role.serial) {
          nums.add((role, n, w.x));
          continue;
        }
      }
      final hasQty = nums.any((e) => e.$1 == _Role.qty);
      if ((role == _Role.qty || role == _Role.unit) && !hasQty && _qtyWithUnit(t) != null) {
        final (q, u) = _qtyWithUnit(t)!;
        nums.add((_Role.qty, _Num(q), w.x));
        p.unit = u;
        continue;
      }
      if ((role == _Role.unit || role == _Role.qty) && _isUnit(t)) {
        unitWords.add(t);
        continue;
      }
      nameWords.add(t);
    }
    // Leading unit word in the name ("Yds. 3m. S.Paper") → unit.
    while (nameWords.length > 1 && _isUnit(nameWords.first)) {
      unitWords.add(nameWords.removeAt(0));
    }
    if (p.unit == null && unitWords.isNotEmpty) p.unit = _normUnit(unitWords.first);
    p.name = _trimJunk(nameWords).join(' ');

    nums.removeWhere((e) => e.$2.value <= 0);
    nums.sort((a, b) => a.$3.compareTo(b.$3));
    _Num? pick(_Role r) => nums.where((e) => e.$1 == r).map((e) => e.$2).lastOrNull;
    final qty = nums.where((e) => e.$1 == _Role.qty).map((e) => e.$2).firstOrNull;
    final rate = pick(_Role.rate);
    final amount = pick(_Role.amount);
    final amountCount = nums.where((e) => e.$1 == _Role.amount).length;
    if (amountCount > 1 && rate == null || amount == null && rate == null) {
      // Columns didn't separate cleanly: fall back to order and arithmetic.
      _resolve(p, [for (final e in nums) if (e.$1 != _Role.unit) e.$2]);
      return p;
    }
    _resolve(p, const [], qty: qty, rate: rate, amount: amount);
    return p;
  }

  /// Drops OCR noise before an HSN code, the code itself (DMart), the
  /// "L" loose-item marker and a "1)" serial.
  List<T> _stripLeading<T>(List<T> tokens, _ParsedRow p, String Function(T) text, T Function(T, String) withText) {
    final out = tokens.where((t) => !RegExp(r'^[~\\|_:;,.\-—=*`]+$').hasMatch(text(t))).toList();
    final hsn = RegExp(r'^[0-9OoIl$]{4,8}[).:]?(L\.?)?$');
    final glued = RegExp(r'^[0-9OoIl]{4,8}[).:]?L\.?(?=[A-Za-z])');
    for (var i = 0; i < min(3, out.length); i++) {
      final t = text(out[i]);
      // Only short noise may come before a code: "Pe 190531 UNIBIC".
      if (i > 0 && out.take(i).any((x) => text(x).length > 3)) break;
      if (hsn.hasMatch(t) && RegExp(r'\d{3}').hasMatch(t)) {
        out.removeRange(0, i + 1);
        p.startsWithCode = true;
        break;
      }
      if (glued.hasMatch(t) && RegExp(r'\d{3}').hasMatch(t)) {
        out[i] = withText(out[i], t.replaceFirst(glued, ''));
        out.removeRange(0, i);
        p.startsWithCode = true;
        break;
      }
    }
    if (p.startsWithCode && out.isNotEmpty && RegExp(r'^L\.?$').hasMatch(text(out.first))) {
      out.removeAt(0);
      p.loose = true;
    }
    if (p.startsWithCode && tokens.isNotEmpty && RegExp(r'L\.?$').hasMatch(text(tokens.first))) p.loose = true;
    if (out.isNotEmpty && RegExp(r'^\(?\d{1,2}[)]$').hasMatch(text(out.first))) {
      out.removeAt(0);
      p.startsWithSerial = true;
    }
    return out;
  }

  /// For names printed in capitals (supermarket bills), short mixed-case
  /// or symbol tokens at either end are OCR noise from ticks and folds.
  static List<String> _trimJunk(List<String> words) {
    final letterWords = words.where((w) => _hasLetters(w, 2)).toList();
    final letters = letterWords.join();
    final upper = RegExp('[A-Z]').allMatches(letters).length;
    final lower = RegExp('[a-z]').allMatches(letters).length;
    final capsName = letterWords.length >= 2 && upper >= (upper + lower) * 0.7;
    final out = words.where((w) => !w.contains('%')).toList();
    bool junk(String w) =>
        RegExp(r'^[A-Za-z]$').hasMatch(w) && w != 'A' ||
        (w.length <= 3 && w != w.toUpperCase() && RegExp(r'[a-z]').hasMatch(w)) ||
        RegExp(r'^[^A-Za-z0-9]+$').hasMatch(w);
    final moneyish = RegExp(r'^\d+[:.,]\d{1,2}$|^\d*[:.,]\d\d$');
    out.removeWhere((w) => moneyish.hasMatch(w));
    if (capsName) {
      bool leadingNoise(String w) => junk(w) || RegExp(r'^[0-9OoIl]{1,3}$').hasMatch(w);
      while (out.length > 1 && leadingNoise(out.first)) {
        out.removeAt(0);
      }
      while (out.length > 1 && junk(out.last)) {
        out.removeLast();
      }
    }
    return out;
  }

  _ParsedRow? _parseFree(List<_Word> words) {
    final p = _ParsedRow();
    final tokens = _stripLeading(words.map((w) => w.text).toList(), p, (t) => t, (_, t) => t);
    if (tokens.isEmpty) return null;

    // Trailing numbers (from the right) are quantity / rate / amount.
    final trailing = <_Num>[];
    while (tokens.isNotEmpty) {
      final n = _parseNum(tokens.last);
      if (n == null || _hasLetters(tokens.last, 1)) break;
      trailing.insert(0, n);
      tokens.removeLast();
    }
    // Leading quantity ("2 PCS. Paint brush").
    double? leadingQty;
    if (tokens.length > 1) {
      final n = _parseNum(tokens.first);
      if (n != null && !_hasLetters(tokens.first, 1) && n.value > 0 && n.value <= 999) {
        leadingQty = n.value;
        tokens.removeAt(0);
      }
    }
    if (tokens.length > 1 && _isUnit(tokens.first)) p.unit = _normUnit(tokens.removeAt(0));
    if (tokens.length > 1 && _isDitto(tokens.first)) {
      tokens.removeAt(0);
      p.dittoUnit = true;
    }

    // Keep at most three trailing numbers; extra ones belong to the name
    // ("SUNDARAM A5 LB 172 | 5 | 42.00 | 210.00").
    while (trailing.length > 3) {
      final extra = trailing.removeAt(0);
      if (extra.decimals == 0 && extra.value > 0) tokens.add(_fmt(extra.value));
    }
    trailing.removeWhere((n) => n.value <= 0);
    _resolve(p, trailing, leadingQty: leadingQty);
    // If the qty-rate-amount check used fewer numbers, return a whole
    // number to the name ("PL WATER BTLE SML 4 | 1 | 99.00 | 99.00").
    final unused = p.unusedLeading;
    if (unused != null && unused == unused.roundToDouble()) tokens.add(_fmt(unused));
    p.name = _trimJunk(tokens).join(' ');
    return p;
  }

  /// Fills qty/rate/amount on [p] from [nums] (left to right), checking
  /// qty × rate = amount where possible.
  void _resolve(
    _ParsedRow p,
    List<_Num> nums, {
    _Num? qty,
    _Num? rate,
    _Num? amount,
    double? leadingQty,
  }) {
    if (nums.isEmpty && amount == null) return;
    bool near(double a, double b) => (a - b).abs() <= max(0.6, 0.02 * b.abs());

    if (amount != null || rate != null) {
      // Columns known.
      final a = amount?.value;
      final r = rate?.value;
      final q = qty?.value ?? leadingQty;
      p.amount = a ?? (r != null ? r * (q ?? 1) : null);
      p.rate = r ?? (a != null && q != null && q > 0 ? _round2(a / q) : a);
      if (q != null) {
        p.qty = q;
      } else if (a != null && r != null && r > 0) {
        final guess = _guessQty(a / r);
        if (guess == guess.roundToDouble() || p.loose) {
          p.qty = guess;
          if (guess != guess.roundToDouble()) p.unit ??= 'kg';
        } else {
          // Prices don't agree; trust the amount.
          p.qty = 1;
          p.rate = a;
          p.lowConfidence = true;
        }
      } else {
        p.qty = 1;
      }
      if (a != null && r != null && q != null && !near(q * r, a)) p.lowConfidence = true;
      if (qty != null && qty.decimals == 3) p.unit ??= 'kg';
      return;
    }

    final a = nums.last;
    if (!_moneyLike(a)) return;
    p.amount = a.value;
    final before = nums.sublist(0, nums.length - 1);

    if (before.length >= 2) {
      var q = before[before.length - 2], r = before.last;
      if (near(q.value * r.value, a.value)) {
        // Which is the quantity? Weights have 3 decimals, prices 2.
        final swap = r.decimals == 3 && q.decimals != 3 ||
            q.decimals == 2 && r.decimals != 2 && r.decimals != 3 ||
            q.decimals == r.decimals && q.decimals != 3 && q.value > r.value;
        if (swap) (q, r) = (r, q);
        p.qty = q.value;
        p.rate = r.value;
        if (q.decimals == 3) p.unit ??= 'kg';
        if (before.length > 2) p.unusedLeading = before.first.value;
        return;
      }
    }
    if (before.isNotEmpty) {
      final x = before.last;
      if (before.length >= 2) p.unusedLeading = before[before.length - 2].value;
      if (leadingQty != null && near(leadingQty * x.value, a.value)) {
        p.qty = leadingQty;
        p.rate = x.value;
        return;
      }
      if (near(x.value, a.value)) {
        p.qty = leadingQty ?? 1;
        p.rate = x.value;
        if (leadingQty != null && !near(leadingQty * x.value, a.value)) p.unusedLeading = leadingQty;
        return;
      }
      // Weighed item whose weight wasn't read: weight = amount / rate.
      final w = a.value / x.value;
      if (x.value > a.value * 0.2 && w > 0.04 && w < 60 && x.decimals > 0) {
        p.rate = x.value;
        p.qty = _guessQty(w);
        if (p.qty != w.roundToDouble()) p.unit ??= 'kg';
        p.lowConfidence = true;
        return;
      }
      if (x.decimals == 0 && x.value >= 1 && x.value <= 99 && x.value < a.value) {
        p.qty = x.value;
        p.rate = _round2(a.value / x.value);
        p.lowConfidence = !near(p.rate! * x.value, a.value);
        return;
      }
    }
    p.qty = leadingQty ?? 1;
    p.rate = _round2(a.value / p.qty!);
    if (before.isNotEmpty) p.lowConfidence = true;
  }

  // -------------------------------------------------------------- helpers

  static double _guessQty(double q) {
    final r = q.roundToDouble();
    if ((q - r).abs() < 0.02) return r;
    return (q * 1000).round() / 1000;
  }

  static double _round2(double v) => (v * 100).round() / 100;

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  static bool _moneyLike(_Num n) => n.value > 0 && (n.decimals > 0 || n.money || n.value < 100000);

  /// Parses a number as printed on bills: "3,000.00", "600-", "75/-",
  /// "141,50", "399/00", OCR's O→0 and l→1 inside numbers.
  static _Num? _parseNum(String raw) {
    var s = raw.trim().replaceAll(RegExp(r'^[“”"\x27`:;(]+|[“”"\x27`:;)]+$'), '');
    var money = false;
    s = s.replaceFirst(RegExp(r'^(₹|rs\.?|inr|\+)', caseSensitive: false), '');
    if (RegExp(r'(/-|-|/)$').hasMatch(s)) {
      money = true;
      s = s.replaceFirst(RegExp(r'(/-|-|/)$'), '');
    }
    s = s.replaceAll(RegExp(r'[.,]+$'), '');
    if (s.isEmpty) return null;
    final digits = RegExp(r'\d').allMatches(s).length;
    if (digits == 0 || digits < s.replaceAll(RegExp(r'[.,/]'), '').length * 0.6) return null;
    s = s.replaceAll(RegExp('[Oo]'), '0').replaceAll(RegExp('[lI|]'), '1');
    if (RegExp(r'[^0-9.,/]').hasMatch(s)) return null;
    if (RegExp(r'^\d+/\d{2}$').hasMatch(s)) s = s.replaceFirst('/', '.');
    if (s.contains('/')) return null;
    if (RegExp(r'^\d+,\d{2}$').hasMatch(s)) s = s.replaceFirst(',', '.');
    s = s.replaceAll(',', '');
    if ('.'.allMatches(s).length > 1) return null;
    final v = double.tryParse(s);
    if (v == null) return null;
    final dot = s.indexOf('.');
    final decimals = dot < 0 ? 0 : s.length - dot - 1;
    return _Num(v, decimals: decimals, money: money || decimals == 2);
  }

  static (double, String)? _qtyWithUnit(String t) {
    final m = RegExp(r'^(\d+(?:\.\d+)?)\s*([A-Za-z]+)\.?$').firstMatch(t);
    if (m == null || !_units.contains(m.group(2)!.toLowerCase())) return null;
    return (double.parse(m.group(1)!), _normUnit(m.group(2)!));
  }

  static bool _isUnit(String t) => _units.contains(t.toLowerCase().replaceAll(RegExp(r'[.,:]+$'), ''));

  static String _normUnit(String t) {
    final u = t.toLowerCase().replaceAll(RegExp(r'[.,:]+$'), '');
    return switch (u) {
      'pc' || 'pcs' || 'piece' || 'pieces' || 'nos' || 'no' => 'pcs',
      'kilo' || 'kilos' || 'kgs' => 'kg',
      'gm' || 'gms' => 'g',
      'liter' || 'litre' || 'lt' || 'l' => 'L',
      'mtr' || 'mtrs' || 'meter' => 'm',
      'gal' || 'gals' => 'gal',
      'yd' || 'yds' => 'yd',
      'dz' => 'dozen',
      'pkts' => 'pkt',
      _ => u,
    };
  }

  static bool _isDitto(String t) => RegExp(r'''^["“”„'″]{1,2}$''').hasMatch(t);

  static bool _isSerial(String t) => RegExp(r'^\(?\d{1,2}[).]$').hasMatch(t);

  static bool _hasLetters(String s, int n) => RegExp(r'[A-Za-zऀ-ॿ]').allMatches(s).length >= n;

  static bool _isNameWord(String t) =>
      _hasLetters(t, 3) && !RegExp(r'^(rs\.?|inr)$', caseSensitive: false).hasMatch(t);

  static double? _lastMoney(List<_Word> words) {
    for (final w in words.reversed) {
      final n = _parseNum(w.text);
      if (n != null && n.value > 0 && !_hasLetters(w.text, 1) && !w.text.contains('%')) return n.value;
    }
    return null;
  }

  static double _median(List<double> v) {
    if (v.isEmpty) return 20;
    final s = v.toList()..sort();
    return s[s.length ~/ 2];
  }

  String? _store(List<_Row> rows, double firstItemTop) {
    final top = rows.take(max(4, rows.length ~/ 4)).where((r) => r.bottom < firstItemTop).toList();
    if (top.isEmpty) return null;
    final all = top.map((r) => r.text.toLowerCase().replaceAll(RegExp(r'[^a-z0 ]'), '')).join(' ');
    for (final e in _chains.entries) {
      if (all.contains(e.key)) return e.value;
    }
    OcrFragment? best;
    for (final r in top) {
      for (final f in r.fragments) {
        final letters = RegExp(r'[A-Za-z]').allMatches(f.text).length;
        final digits = RegExp(r'\d').allMatches(f.text).length;
        if (letters < 4 || digits > letters * 0.25 || _summary.hasMatch(f.text) || _notStore.hasMatch(f.text)) {
          continue;
        }
        if (best == null || f.height > best.height * 1.15) best = f;
      }
    }
    if (best == null) return null;
    final name = best.text.replaceAll(RegExp(r'[^A-Za-z0-9&\x27 .-]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    return name.isEmpty ? null : cleaner.clean(name);
  }

  static final _dateRe = RegExp(r'\b(\d{1,2})\s*[/.-]\s*(\d{1,2})\s*[/.-]\s*(\d{2,4})\b');
  static final _monthDateRe = RegExp(
    r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s*(\d{1,2})\s*[/,.-]?\s*(\d{4})',
    caseSensitive: false,
  );

  DateTime? _date(List<_Row> rows) {
    for (final r in rows) {
      final text = r.text;
      final m = _dateRe.firstMatch(text);
      if (m != null) {
        final d = int.parse(m.group(1)!), mo = int.parse(m.group(2)!);
        var y = int.parse(m.group(3)!);
        if (y < 100) y += 2000;
        if (d >= 1 && d <= 31 && mo >= 1 && mo <= 12 && y >= 1990 && y <= 2100) return DateTime(y, mo, d);
      }
      final mm = _monthDateRe.firstMatch(text);
      if (mm != null) {
        const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
        return DateTime(int.parse(mm.group(3)!), months.indexOf(mm.group(1)!.toLowerCase()) + 1, int.parse(mm.group(2)!));
      }
    }
    return null;
  }
}

class _ParsedRow {
  String name = '';
  double? qty;
  String? unit;
  double? rate;
  double? amount;
  bool lowConfidence = false;
  bool startsWithSerial = false;
  bool startsWithCode = false;
  bool dittoUnit = false;
  bool loose = false;
  double? unusedLeading;
}

class _PendingNumbers {
  _PendingNumbers(this.parsed, this.bottom);
  final _ParsedRow parsed;
  final double bottom;
}

/// Similarity of two item names (0–1), tolerant of OCR noise.
double nameSimilarity(String a, String b) {
  String norm(String s) => normalizeText(s).replaceAll(' ', '');
  final x = norm(a), y = norm(b);
  if (x.isEmpty || y.isEmpty) return 0;
  if (x == y) return 1;
  Set<String> grams(String s) => {for (var i = 0; i < s.length - 1; i++) s.substring(i, i + 2)};
  final gx = grams(x), gy = grams(y);
  if (gx.isEmpty || gy.isEmpty) return x == y ? 1 : 0;
  return 2 * gx.intersection(gy).length / (gx.length + gy.length);
}
