/// Turns raw receipt item text into a readable name:
/// `AMUL BUTTER-500g` → `Amul Butter 500 g`, `GOWARDHAN PREMI-11t` →
/// `Gowardhan Premi 1 L`.
class ItemNameCleaner {
  const ItemNameCleaner();

  /// Common short forms on Indian supermarket bills. Kept conservative:
  /// a wrong expansion is worse than leaving the short form.
  static const Map<String, String> _expansions = {
    'prmium': 'Premium', 'premum': 'Premium', 'prem': 'Premium',
    'chee': 'Cheese', 'kshmir': 'Kashmiri', 'kashmir': 'Kashmiri',
    'liqud': 'Liquid', 'liq': 'Liquid', 'doub': 'Double', 'pow': 'Powder', 'pwdr': 'Powder',
    'btle': 'Bottle', 'btl': 'Bottle', 'wtr': 'Water', 'antisp': 'Antiseptic', 'antise': 'Antiseptic',
    'refreshi': 'Refreshing', 'orign': 'Original', 'shin': 'Shine', 'fridg': 'Fridge', 'strg': 'Storage',
    'scrubb': 'Scrubber', 'silvr': 'Silver', 'purpe': 'Purple', 'cotto': 'Cotton', 'kalimu': 'Kalimuch',
    'chhole': 'Chhole', 'asafoet': 'Asafoetida', 'mixe': 'Mixed', 'aer': 'Aer', 'tom': 'Tomato',
    'swt': 'Sweet', 'gulabj': 'Gulab Jamun', 'khaman': 'Khaman', 'sandaltal': 'Sandal Talc',
    'matche': 'Matches', 'napthal': 'Naphthalene', 'camphr': 'Camphor', 'blnkt': 'Blanket',
    'supr': 'Super', 'sft': 'Soft', 'lad': 'Ladies', 'ld': 'Ladies',
  };

  /// Words kept upper-case (brands and codes).
  static const Set<String> _keepUpper = {
    'jd', 'pt', 'rd', 'bdr', 'pl', 'hd', 'sf', 'opl', 'ubt', 'vtc', 'ng', 'lb', 'gb', 'rbs',
    'hul', 'cfl', 'led', 'tv', 'ac', 'bsj', 'h&s', 'ss', 'gc', 'mp', 'si', 'fr', 'cd', 'la', 'sh',
    'oks', 'cyl', 'mtl', 'gls', 'ii', 'iii', 'iv',
  };

  static final _junk = RegExp(r'''[“”"‘’`~=_|\\{}\[\]<>©®°¢§$*^]''');
  static final _size = RegExp(
    r'(?<![A-Za-z])(\d+(?:\.\d+)?)\s*(kgs?|gms?|g|ml|mi|nl|n1|ltrs?|lt|l|1t)(?![A-Za-z])',
    caseSensitive: false,
  );

  String clean(String raw) {
    var s = raw;
    // "1lt" printed as "11t" by OCR; DMart writes litres as "lt".
    s = s.replaceAllMapped(RegExp(r'(\d)1t\b', caseSensitive: false), (m) => '${m[1]}lt');
    s = s.replaceAll(RegExp(r'-\s*nos\b', caseSensitive: false), ' ');
    // OCR reads "1" as "I" before units: "TATA SALT-Ikg".
    s = s.replaceAllMapped(RegExp(r'(?<=[\s-])I(?=(kg|g|gm|ml|lt|ltr)\b)', caseSensitive: false), (_) => '1');
    s = s.replaceAll(_junk, ' ');
    s = s.replaceAll(RegExp(r'\s-+(?=\S)|(?<=\S)-+\s|^-+|-+$|--+'), ' ');
    s = s.replaceAllMapped(RegExp(r'(?<=[A-Za-z])-(?=\d)'), (_) => ' ');
    s = s.replaceAllMapped(_size, (m) {
      final unit = switch (m[2]!.toLowerCase()) {
        'kg' || 'kgs' => 'kg',
        'g' || 'gm' || 'gms' => 'g',
        'ml' || 'mi' || 'nl' || 'n1' => 'ml',
        _ => 'L',
      };
      return ' ${m[1]} $unit ';
    });
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    s = s.replaceAll(RegExp(r'\(\s+'), '(').replaceAll(RegExp(r'\s+\)'), ')');
    s = s.replaceAll(RegExp(r'^[\s,.:;)-]+|[\s,.:;-]+$'), '');
    if (s.isEmpty) return s;
    return s.split(' ').map(_word).join(' ');
  }

  String _word(String w) {
    final lead = RegExp(r'^[(\[]+').firstMatch(w)?.group(0) ?? '';
    if (lead.isNotEmpty) return lead + _word(w.substring(lead.length));
    if (w.isEmpty) return w;
    final lower = w.toLowerCase();
    final bare = lower.replaceAll(RegExp(r'[.,:;]+$'), '');
    if (_expansions.containsKey(bare)) return _expansions[bare]!;
    if (_keepUpper.contains(bare)) return w.toUpperCase().replaceAll(RegExp(r'[.,:;]+$'), '');
    if (w == 'L' || w == 'kg' || w == 'g' || w == 'ml') return w;
    if (RegExp(r'^\d').hasMatch(w)) return w;
    // Initials and abbreviations with dots: "W.P.S.", "G.C."
    if (RegExp(r'^([A-Za-z]\.){2,}[A-Za-z]?\.?$').hasMatch(w)) return w.toUpperCase();
    // "S.PAPER" → "S.Paper"
    if (RegExp(r'^[A-Za-z]\.[A-Za-z]{2,}$').hasMatch(w)) {
      return '${w[0].toUpperCase()}.${w[2].toUpperCase()}${w.substring(3).toLowerCase()}';
    }
    if (w.length <= 3 && w == w.toUpperCase() && RegExp(r'[A-Z]').hasMatch(w) && !_isWord(lower)) {
      return w; // short code like "A5", "W.P.S."
    }
    final trimmed = w.replaceAll(RegExp(r'[.,:;]+$'), '');
    if (trimmed.isEmpty) return '';
    return trimmed
        .split('-')
        .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1).toLowerCase())
        .join('-');
  }

  static const _common = {'and', 'the', 'of', 'for', 'new', 'pc', 'set', 'my', 'day', 'age', 'fan', 'ka'};
  bool _isWord(String w) => _common.contains(w);
}
