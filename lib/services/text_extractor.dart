import '../core/text.dart';
import '../domain/models.dart';

/// What [TextExtractor] found in free text.
class Extraction {
  const Extraction({
    required this.title,
    this.amount,
    this.quantity,
    this.unit,
    this.dueAt,
  });

  /// The text with the extracted bits removed, tidied for use as a title.
  final String title;
  final double? amount;
  final double? quantity;
  final String? unit;
  final DateTime? dueAt;

  bool get hasDetails =>
      amount != null || quantity != null || dueAt != null;
}

/// Pulls amounts, quantities and due dates out of typed or spoken text:
/// "pay gas bill 950 by 12th" → title "pay gas bill", ₹950, due on the 12th.
class TextExtractor {
  TextExtractor({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  static const _months = {
    'jan': 1, 'january': 1, 'feb': 2, 'february': 2, 'mar': 3, 'march': 3,
    'apr': 4, 'april': 4, 'may': 5, 'jun': 6, 'june': 6, 'jul': 7, 'july': 7,
    'aug': 8, 'august': 8, 'sep': 9, 'sept': 9, 'september': 9, 'oct': 10,
    'october': 10, 'nov': 11, 'november': 11, 'dec': 12, 'december': 12,
  };

  static const _weekdays = {
    'monday': 1, 'mon': 1, 'somvar': 1, 'somwar': 1, 'सोमवार': 1,
    'tuesday': 2, 'tue': 2, 'mangalvar': 2, 'mangalwar': 2, 'मंगलवार': 2,
    'wednesday': 3, 'wed': 3, 'budhvar': 3, 'budhwar': 3, 'बुधवार': 3,
    'thursday': 4, 'thu': 4, 'guruvar': 4, 'guruwar': 4, 'गुरुवार': 4,
    'friday': 5, 'fri': 5, 'shukravar': 5, 'shukrawar': 5, 'शुक्रवार': 5,
    'saturday': 6, 'sat': 6, 'shanivar': 6, 'shaniwar': 6, 'शनिवार': 6,
    'sunday': 7, 'sun': 7, 'ravivar': 7, 'raviwar': 7, 'रविवार': 7,
  };

  static const _units = {
    'kg': 'kg', 'kgs': 'kg', 'kilo': 'kg', 'kilos': 'kg', 'g': 'g', 'gm': 'g',
    'gms': 'g', 'gram': 'g', 'grams': 'g', 'l': 'L', 'ltr': 'L', 'ltrs': 'L',
    'litre': 'L', 'litres': 'L', 'liter': 'L', 'liters': 'L', 'ml': 'ml',
    'pc': 'pcs', 'pcs': 'pcs', 'piece': 'pcs', 'pieces': 'pcs', 'packet': 'pkt',
    'packets': 'pkt', 'pkt': 'pkt', 'pack': 'pkt', 'dozen': 'dozen', 'dz': 'dozen',
    'bottle': 'bottle', 'bottles': 'bottle', 'box': 'box', 'boxes': 'box',
  };

  static final _amountRe = RegExp(
    r'(?:₹|rs\.?|inr|rupees?)\s*([0-9][0-9,]*(?:\.[0-9]{1,2})?)'
    r'|([0-9][0-9,]*(?:\.[0-9]{1,2})?)\s*(?:₹|rs\.?|inr|rupees?|rupaye|rupaiye)\b',
    caseSensitive: false,
  );

  static final _qtyRe = RegExp(
    r'\b([0-9]+(?:\.[0-9]+)?)\s*(kgs?|kilos?|gms?|grams?|g|ltrs?|litres?|liters?|l|ml|pcs?|pieces?|packets?|pkt|pack|dozen|dz|bottles?|box(?:es)?)\b',
    caseSensitive: false,
  );

  static final _ordinalDayRe = RegExp(
    r'\b(?:by|on|before|due(?: on| by)?|till|until|tak)?\s*(?:the\s+)?([0-9]{1,2})(st|nd|rd|th)\b'
    r'(?:\s+(?:of\s+)?([a-z]+))?',
    caseSensitive: false,
  );

  static final _numericDateRe = RegExp(
    r'\b(?:by|on|before|due(?: on| by| date)?:?)?\s*([0-9]{1,2})[-/]([0-9]{1,2})(?:[-/]([0-9]{2,4}))?\b',
    caseSensitive: false,
  );

  static final _dayMonthRe = RegExp(
    r'\b(?:by|on|before|due(?: on| by)?:?)?\s*([0-9]{1,2})[\s-]+([a-z]{3,9})(?:[\s,-]+([0-9]{2,4}))?\b',
    caseSensitive: false,
  );

  static final _monthDayRe = RegExp(
    r'\b(?:by|on|before|due(?: on| by)?:?)?\s*([a-z]{3,9})[\s-]+([0-9]{1,2})(?:st|nd|rd|th)?(?:[\s,-]+([0-9]{4}))?\b',
    caseSensitive: false,
  );

  static final _relativeRe = RegExp(
    r'\b(today|aaj|tonight|tomorrow|tmrw|kal|day after tomorrow|parso|parson)\b|(आज|कल|परसों)',
    caseSensitive: false,
  );

  static final _weekdayRe = RegExp(
    r'\b(?:by|on|this|next|agle|is)?\s*(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun|somvar|somwar|mangalvar|mangalwar|budhvar|budhwar|guruvar|guruwar|shukravar|shukrawar|shanivar|shaniwar|ravivar|raviwar)\b|(सोमवार|मंगलवार|बुधवार|गुरुवार|शुक्रवार|शनिवार|रविवार)',
    caseSensitive: false,
  );

  static final _bareNumberRe = RegExp(r'(?:^|\s)([0-9]{2,7}(?:\.[0-9]{1,2})?)(?=\s|$)');

  Extraction extract(String input, {EntryType? type}) {
    var text = ' ${input.trim()} ';
    double? amount;
    double? quantity;
    String? unit;
    DateTime? due;

    // Dates first, so "12/11" isn't read as an amount.
    final dateHit = _findDate(text);
    if (dateHit != null) {
      due = dateHit.$1;
      text = text.replaceRange(dateHit.$2.start, dateHit.$2.end, ' ');
    }

    final amountMatch = _amountRe.firstMatch(text);
    if (amountMatch != null) {
      amount = _parseNum(amountMatch.group(1) ?? amountMatch.group(2));
      text = text.replaceRange(amountMatch.start, amountMatch.end, ' ');
    }

    final qtyMatch = _qtyRe.firstMatch(text);
    if (qtyMatch != null) {
      quantity = _parseNum(qtyMatch.group(1));
      unit = _units[qtyMatch.group(2)!.toLowerCase()];
      text = text.replaceRange(qtyMatch.start, qtyMatch.end, ' ');
    }

    // A bare number in a bill ("electricity bill 1250") is the amount.
    if (amount == null && type == EntryType.bill) {
      final bare = _bareNumberRe.firstMatch(text);
      if (bare != null) {
        amount = _parseNum(bare.group(1));
        text = text.replaceRange(bare.start, bare.end, ' ');
      }
    }

    return Extraction(
      title: _tidy(text),
      amount: amount,
      quantity: quantity,
      unit: unit,
      dueAt: due,
    );
  }

  (DateTime, Match)? _findDate(String text) {
    final today = _today();

    final rel = _relativeRe.firstMatch(text);
    if (rel != null) {
      final word = (rel.group(1) ?? rel.group(2))!.toLowerCase();
      final days = switch (word) {
        'today' || 'aaj' || 'tonight' || 'आज' => 0,
        'tomorrow' || 'tmrw' || 'kal' || 'कल' => 1,
        _ => 2,
      };
      return (today.add(Duration(days: days)), rel);
    }

    final numeric = _numericDateRe.firstMatch(text);
    if (numeric != null) {
      final d = int.parse(numeric.group(1)!);
      final m = int.parse(numeric.group(2)!);
      final yRaw = numeric.group(3);
      if (_validDay(d) && m >= 1 && m <= 12) {
        var y = yRaw == null ? null : int.parse(yRaw);
        if (y != null && y < 100) y += 2000;
        return (_resolve(today, d, m, y), numeric);
      }
    }

    for (final m in _dayMonthRe.allMatches(text)) {
      final month = _months[m.group(2)!.toLowerCase()];
      final d = int.parse(m.group(1)!);
      if (month != null && _validDay(d)) {
        final y = m.group(3) == null ? null : _year(m.group(3)!);
        return (_resolve(today, d, month, y), m);
      }
    }

    for (final m in _monthDayRe.allMatches(text)) {
      final month = _months[m.group(1)!.toLowerCase()];
      final d = int.parse(m.group(2)!);
      if (month != null && _validDay(d)) {
        final y = m.group(3) == null ? null : _year(m.group(3)!);
        return (_resolve(today, d, month, y), m);
      }
    }

    final ord = _ordinalDayRe.firstMatch(text);
    if (ord != null) {
      final d = int.parse(ord.group(1)!);
      final month = _months[(ord.group(3) ?? '').toLowerCase()];
      if (_validDay(d)) {
        if (month != null) return (_resolve(today, d, month, null), ord);
        // "by 12th": the next 12th from today.
        var candidate = DateTime(today.year, today.month, d);
        if (candidate.month != today.month) {
          candidate = DateTime(today.year, today.month + 1, 0);
        }
        if (candidate.isBefore(today)) {
          candidate = DateTime(today.year, today.month + 1, d);
        }
        final trimmedEnd = ord.group(3) != null && month == null
            ? ord.start + ord.group(0)!.lastIndexOf(ord.group(3)!)
            : ord.end;
        return (candidate, _Span(ord.start, trimmedEnd));
      }
    }

    final wd = _weekdayRe.firstMatch(text);
    if (wd != null) {
      final word = (wd.group(1) ?? wd.group(2))!.toLowerCase();
      final target = _weekdays[word]!;
      var delta = (target - today.weekday + 7) % 7;
      if (delta == 0) delta = 7;
      return (today.add(Duration(days: delta)), wd);
    }
    return null;
  }

  DateTime _resolve(DateTime today, int d, int m, int? y) {
    var candidate = DateTime(y ?? today.year, m, d);
    if (y == null && candidate.isBefore(today.subtract(const Duration(days: 31)))) {
      candidate = DateTime(today.year + 1, m, d);
    }
    return candidate;
  }

  int _year(String raw) {
    final y = int.parse(raw);
    return y < 100 ? 2000 + y : y;
  }

  bool _validDay(int d) => d >= 1 && d <= 31;

  DateTime _today() {
    final n = _now();
    return DateTime(n.year, n.month, n.day);
  }

  static double? _parseNum(String? raw) =>
      raw == null ? null : double.tryParse(raw.replaceAll(',', ''));

  static String _tidy(String text) {
    var t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    t = t.replaceAll(
      RegExp(r'\s+(by|on|before|due|till|until|tak|of|for|the)$', caseSensitive: false),
      '',
    );
    t = t.replaceAll(RegExp(r'^[\s,.:;-]+|[\s,.:;-]+$'), '');
    return t;
  }
}

class _Span implements Match {
  _Span(this.start, this.end);
  @override
  final int start;
  @override
  final int end;
  @override
  String? group(int group) => null;
  @override
  String? operator [](int group) => null;
  @override
  List<String?> groups(List<int> groupIndices) => const [];
  @override
  int get groupCount => 0;
  @override
  String get input => '';
  @override
  Pattern get pattern => '';
}

/// A bill found in a bank or biller SMS (spec FR-43 / FR-44).
class SmsBill {
  const SmsBill({
    required this.title,
    required this.categoryId,
    this.amount,
    this.dueAt,
  });

  final String title;
  final String categoryId;
  final double? amount;
  final DateTime? dueAt;
}

/// Recognises bill reminders in SMS text. Runs entirely on the device.
class SmsBillParser {
  SmsBillParser({DateTime Function()? now})
      : _extractor = TextExtractor(now: now);

  final TextExtractor _extractor;

  static const _billers = <(List<String>, String, String)>[
    (['credit card', 'card ending', 'card no', 'total amount due', 'min amt due', 'minimum amount due'], 'bills.card', 'Credit card bill'),
    (['electricity', 'msedcl', 'mahavitaran', 'bescom', 'tata power', 'adani electricity', 'bses', 'tneb', 'cesc', 'energy bill', 'units consumed'], 'bills.electricity', 'Electricity bill'),
    (['piped gas', 'mgl', 'igl', 'gas bill', 'lpg', 'cylinder', 'indane', 'hp gas', 'bharat gas'], 'bills.gas', 'Gas bill'),
    (['water bill', 'water charges', 'water tax'], 'bills.water', 'Water bill'),
    (['broadband', 'fiber', 'fibernet', 'jiofiber', 'airtel xstream', 'postpaid', 'recharge', 'mobile bill', 'dth', 'tata play'], 'bills.internet', 'Internet / mobile bill'),
    (['premium', 'policy', 'lic', 'insurance'], 'bills.insurance', 'Insurance premium'),
    (['emi', 'loan'], 'bills.rent', 'Loan EMI'),
    (['school fee', 'tuition fee', 'fees due'], 'bills.fees', 'School fees'),
  ];

  static final _billSignal = RegExp(
    r'\b(due|payable|pay by|bill|premium|emi|outstanding|amount due|amt due|last date)\b',
    caseSensitive: false,
  );

  static final _dueDateRe = RegExp(
    r'(?:due(?:\s+date)?|pay(?:able)?\s+by|last\s+date|before|by)\s*(?:on|is|:)?\s*([0-9]{1,2}[-/.][0-9]{1,2}(?:[-/.][0-9]{2,4})?|[0-9]{1,2}[\s-]?[a-z]{3,9}(?:[\s,-]?[0-9]{2,4})?|[a-z]{3,9}\s+[0-9]{1,2}(?:,?\s*[0-9]{4})?)',
    caseSensitive: false,
  );

  /// Returns a bill when [sms] looks like a bill reminder, else null.
  SmsBill? parse(String sms) {
    if (!_billSignal.hasMatch(sms)) return null;
    final lower = normalizeText(sms);
    var category = 'bills';
    var title = 'Bill payment';
    for (final (keys, cat, name) in _billers) {
      if (keys.any((k) => ' $lower '.contains(' $k '))) {
        category = cat;
        title = name;
        break;
      }
    }
    final amountMatch = TextExtractor._amountRe.firstMatch(sms);
    final amount = amountMatch == null
        ? null
        : TextExtractor._parseNum(amountMatch.group(1) ?? amountMatch.group(2));
    DateTime? due;
    // "Amount Due INR 12" also looks like a date phrase; take the first
    // candidate that really is a date.
    for (final m in _dueDateRe.allMatches(sms)) {
      due = _extractor.extract('on ${m.group(1)!.replaceAll('.', '-')}').dueAt;
      if (due != null) break;
    }
    if (amount == null && due == null) return null;
    return SmsBill(title: title, categoryId: category, amount: amount, dueAt: due);
  }
}
