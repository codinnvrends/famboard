/// Text helpers shared by the categorizer, duplicate check and search.
library;

final _punctuation = RegExp(r'''[!-/:-@\[-`{-~।॥,“”‘’"']''');
final _spaces = RegExp(r'\s+');

/// Lower-cases, strips punctuation and collapses whitespace. Keeps letters in
/// any script, so Devanagari input works.
String normalizeText(String input) => input
    .toLowerCase()
    .replaceAll(_punctuation, ' ')
    .replaceAll(_spaces, ' ')
    .trim();

/// Splits normalized text into tokens.
List<String> tokenize(String input) {
  final norm = normalizeText(input);
  if (norm.isEmpty) return const [];
  return norm.split(' ');
}

/// Words that carry no meaning for categorizing or duplicate checks.
const stopWords = <String>{
  'a', 'an', 'the', 'of', 'for', 'to', 'and', 'or', 'in', 'on', 'at', 'is',
  'by', 'with', 'some', 'more', 'buy', 'get', 'need', 'needs', 'new', 'please',
  'pls', 'plz', 'our', 'my', 'we', 'ka', 'ki', 'ke', 'ko', 'hai', 'he', 'ho',
  'lana', 'lao', 'le', 'lena', 'aur', 'bhi', 'kar', 'karo', 'karna', 'ek',
  'do', 'kg', 'g', 'gm', 'l', 'ltr', 'ml', 'pc', 'pcs', 'packet', 'packets',
};

/// Levenshtein distance capped at [max] + 1 for speed.
int editDistance(String a, String b, {int max = 2}) {
  if ((a.length - b.length).abs() > max) return max + 1;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    cur[0] = i;
    var rowMin = cur[0];
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost]
          .reduce((x, y) => x < y ? x : y);
      if (cur[j] < rowMin) rowMin = cur[j];
    }
    if (rowMin > max) return max + 1;
    prev = cur;
  }
  return prev[b.length];
}
