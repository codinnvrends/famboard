import '../../core/text.dart';
import '../../domain/categories.dart';
import '../../domain/models.dart';
import 'dictionary.dart';

/// Where a categorization came from.
enum CategorySource { familyOverride, dictionary, fuzzy, typeDefault }

class Categorization {
  const Categorization({
    required this.type,
    required this.categoryId,
    required this.source,
    this.typeDetected = false,
    this.matchedTerm,
  });

  final EntryType type;
  final String categoryId;
  final CategorySource source;

  /// Whether the type came from a keyword ("leaking", "pay", "khatam").
  final bool typeDetected;
  final String? matchedTerm;
}

/// Offline, rule-based categorizer (spec section 6, layers 1–3).
///
/// Runs in well under a millisecond for typical titles; nothing leaves the
/// device.
class Categorizer {
  Categorizer({Map<String, List<String>> terms = categoryTerms}) {
    for (final entry in terms.entries) {
      for (final raw in entry.value) {
        final term = normalizeText(raw);
        if (term.isEmpty) continue;
        if (term.contains(' ')) {
          _phrases.putIfAbsent(term, () => entry.key);
        } else {
          _words.putIfAbsent(term, () => entry.key);
        }
      }
    }
    _fuzzyCandidates = _words.keys.where((w) => w.length > 4).toList();
  }

  final Map<String, String> _phrases = {};

  /// Categories whose words are too general to win over a specific match.
  static const _generic = {'chores.errands'};
  final Map<String, String> _words = {};
  late final List<String> _fuzzyCandidates;

  static const Map<EntryType, List<String>> _typeCues = {
    EntryType.repair: [
      'not working', 'stopped working', 'kaam nahi', 'kaam nahin', 'chal nahi',
      'chalta nahi', 'band ho gaya', 'band hai', 'broken', 'broke', 'leaking',
      'leak', 'leakage', 'fix', 'repair', 'kharab', 'kharaab', 'toot', 'toota',
      'tuta', 'tooti', 'tuti', 'damaged', 'stuck', 'jam', 'noise', 'awaaz',
      'blocked', 'clogged', 'tripping', 'sparking', 'खराब', 'ख़राब', 'टूटा',
      'टूट', 'लीक', 'ठीक करना', 'मरम्मत',
    ],
    EntryType.bill: [
      'pay', 'payment', 'bill', 'due', 'recharge', 'renew', 'renewal', 'emi',
      'rent', 'premium', 'fees', 'fee', 'subscription', 'bharna', 'bharo',
      'bhugtan', 'भुगतान', 'बिल', 'रिचार्ज', 'किराया', 'फ़ीस', 'फीस',
    ],
    EntryType.outOfStock: [
      'finished', 'khatam', 'khatm', 'khtm', 'over', 'out of', 'ran out',
      'run out', 'running low', 'low on', 'empty', 'nahi hai', 'nahin hai',
      'bacha nahi', 'ख़त्म', 'खत्म', 'नहीं है',
    ],
    EntryType.upgrade: [
      'upgrade', 'replace with new', 'replace', 'better', 'new one',
      'purana', 'old one', 'naya', 'nayi', 'बदलना', 'नया',
    ],
    EntryType.task: [
      'call', 'book', 'schedule', 'appointment', 'submit', 'pick up', 'pickup',
      'drop off', 'visit', 'clean', 'renew license', 'apply', 'follow up',
      'remind', 'karwana', 'karvana', 'बुक', 'कॉल',
    ],
  };

  /// Categorizes [title] using [overrides] the family has taught it.
  Categorization categorize(
    String title, {
    List<KeywordOverride> overrides = const [],
  }) {
    final norm = normalizeText(title);
    final tokens = norm.isEmpty ? const <String>[] : norm.split(' ');

    final detected = _detectType(norm, tokens);

    // Layer 1: the family's own corrections.
    final override = _matchOverride(norm, tokens, overrides);
    if (override != null) {
      return Categorization(
        type: detected ?? override.type ?? _typeForCategory(override.categoryId),
        categoryId: override.categoryId,
        source: CategorySource.familyOverride,
        typeDetected: detected != null,
        matchedTerm: override.term,
      );
    }

    // Layer 3: dictionary (phrases first, longest wins; then words).
    String? category;
    String? matched;
    var source = CategorySource.dictionary;
    for (final phrase in _phrasesByLength) {
      if (_containsPhrase(norm, phrase)) {
        category = _phrases[phrase];
        matched = phrase;
        break;
      }
    }
    if (category == null) {
      // Prefer a specific word ("plumber") over a generic one ("call").
      for (final token in tokens) {
        final hit = _words[token] ?? _words[_singular(token)];
        if (hit == null) continue;
        if (category == null || _generic.contains(category)) {
          category = hit;
          matched = token;
          if (!_generic.contains(hit)) break;
        }
      }
    }
    if (category == null) {
      for (final token in tokens) {
        if (token.length <= 4 || stopWords.contains(token)) continue;
        for (final candidate in _fuzzyCandidates) {
          if (editDistance(token, candidate, max: 1) <= 1) {
            category = _words[candidate];
            matched = candidate;
            source = CategorySource.fuzzy;
            break;
          }
        }
        if (category != null) break;
      }
    }

    if (category == null) {
      final type = detected ?? EntryType.needToBuy;
      return Categorization(
        type: type,
        categoryId: defaultCategoryForType[type]!,
        source: CategorySource.typeDefault,
        typeDetected: detected != null,
      );
    }

    final type = detected ?? _typeForCategory(category);
    return Categorization(
      type: type,
      categoryId: _alignCategory(type, category),
      source: source,
      typeDetected: detected != null,
      matchedTerm: matched,
    );
  }

  late final List<String> _phrasesByLength = _phrases.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));

  EntryType? _detectType(String norm, List<String> tokens) {
    // Repairs and stock-outs are the most specific signals, then bills.
    for (final type in const [
      EntryType.repair,
      EntryType.outOfStock,
      EntryType.bill,
      EntryType.upgrade,
      EntryType.task,
    ]) {
      for (final cue in _typeCues[type]!) {
        if (cue.contains(' ')) {
          if (_containsPhrase(norm, cue)) return type;
        } else if (tokens.contains(cue)) {
          return type;
        }
      }
    }
    return null;
  }

  KeywordOverride? _matchOverride(
    String norm,
    List<String> tokens,
    List<KeywordOverride> overrides,
  ) {
    if (overrides.isEmpty) return null;
    KeywordOverride? best;
    for (final o in overrides) {
      if (o.term == norm) return o;
      final matches = o.term.contains(' ')
          ? _containsPhrase(norm, o.term)
          : tokens.contains(o.term);
      if (matches && (best == null || o.term.length > best.term.length)) {
        best = o;
      }
    }
    return best;
  }

  EntryType _typeForCategory(String categoryId) {
    final top = categoryId.split('.').first;
    return switch (top) {
      'bills' => EntryType.bill,
      'repairs' => EntryType.repair,
      'upgrades' => EntryType.upgrade,
      'chores' => EntryType.task,
      _ => categoryId == 'health.appointments'
          ? EntryType.task
          : EntryType.needToBuy,
    };
  }

  /// Keeps type and category consistent: "laptop not working" is a repair of
  /// an appliance, "upgrade fridge" is an appliance purchase.
  String _alignCategory(EntryType type, String category) {
    final parts = category.split('.');
    final top = parts.first;
    final sub = parts.length > 1 ? parts[1] : null;
    switch (type) {
      case EntryType.repair:
        if (top == 'repairs') return category;
        if (top == 'upgrades') {
          return sub == 'electronics' || sub == 'appliances'
              ? 'repairs.appliances'
              : sub == 'furniture'
                  ? 'repairs.carpentry'
                  : 'repairs';
        }
        return top == 'groceries' || top == 'household' ? 'repairs' : category;
      case EntryType.upgrade:
        if (top == 'upgrades') return category;
        if (top == 'repairs') {
          return switch (sub) {
            'appliances' => 'upgrades.appliances',
            'electrical' => 'upgrades.electronics',
            'carpentry' => 'upgrades.furniture',
            _ => 'upgrades',
          };
        }
        return category;
      case EntryType.bill:
        return top == 'bills' ? category : 'bills';
      case EntryType.needToBuy:
      case EntryType.outOfStock:
      case EntryType.task:
        return category;
    }
  }

  static bool _containsPhrase(String norm, String phrase) {
    if (norm == phrase) return true;
    return norm.startsWith('$phrase ') ||
        norm.endsWith(' $phrase') ||
        norm.contains(' $phrase ');
  }

  static String _singular(String token) {
    if (token.length > 3 && token.endsWith('es')) {
      return token.substring(0, token.length - 2);
    }
    if (token.length > 3 && token.endsWith('s')) {
      return token.substring(0, token.length - 1);
    }
    return token;
  }

  /// Terms to learn from when a user re-categorizes [title]: always the whole
  /// title, plus its key words when there are at most two of them (learning
  /// single words from long titles would over-generalise).
  static List<String> learnableTerms(String title) {
    final norm = normalizeText(title);
    if (norm.isEmpty) return const [];
    final tokens = norm
        .split(' ')
        .where((t) => t.length > 2 && !stopWords.contains(t))
        .where((t) => double.tryParse(t) == null)
        .toList();
    return {norm, if (tokens.length <= 2) ...tokens}.toList();
  }
}
