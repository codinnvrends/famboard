import 'receipt_parser.dart';

/// Joins several photos of one long bill. Consecutive photos overlap, so
/// lines at the start of a photo that repeat the end of the previous one
/// are dropped. A matching in order (longest common subsequence) keeps
/// genuinely repeated items, like two separate rows of the same noodles.
class BillMerger {
  const BillMerger({this.window = 60});

  /// How many items at the end of the previous photos are compared.
  final int window;

  ParsedBill merge(List<ParsedBill> pages) {
    if (pages.isEmpty) return ParsedBill(items: []);
    final items = <BillItem>[...pages.first.items];
    for (final page in pages.skip(1)) {
      final tail = items.length > window ? items.sublist(items.length - window) : items;
      final head = page.items.length > window ? page.items.sublist(0, window) : page.items;
      final matched = _matchedInHead(tail, head);
      // Overlap only makes sense at the start of the new photo: ignore
      // matches after a long run of new items.
      var lastMatched = -1;
      for (var j = 0; j < head.length; j++) {
        if (matched.contains(j)) lastMatched = j;
      }
      for (var j = 0; j < page.items.length; j++) {
        if (j <= lastMatched && matched.contains(j)) continue;
        items.add(page.items[j]);
      }
    }
    double? total;
    int? count;
    String? store;
    DateTime? date;
    for (final p in pages) {
      total = p.printedTotal ?? total;
      count = p.printedItemCount ?? count;
      store ??= p.store;
      date ??= p.date;
    }
    return ParsedBill(items: items, store: store, date: date, printedTotal: total, printedItemCount: count);
  }

  static bool same(BillItem a, BillItem b) {
    final sim = nameSimilarity(a.name, b.name);
    final amountsKnown = a.amount != null && b.amount != null;
    if (amountsKnown && (a.amount! - b.amount!).abs() < 0.01) return sim >= 0.35;
    return sim >= 0.8;
  }

  /// Indices in [head] matched to items in [tail], in order.
  Set<int> _matchedInHead(List<BillItem> tail, List<BillItem> head) {
    final n = tail.length, m = head.length;
    final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (var i = n - 1; i >= 0; i--) {
      for (var j = m - 1; j >= 0; j--) {
        dp[i][j] = same(tail[i], head[j])
            ? dp[i + 1][j + 1] + 1
            : (dp[i + 1][j] > dp[i][j + 1] ? dp[i + 1][j] : dp[i][j + 1]);
      }
    }
    final out = <int>{};
    var i = 0, j = 0;
    while (i < n && j < m) {
      if (same(tail[i], head[j]) && dp[i][j] == dp[i + 1][j + 1] + 1) {
        out.add(j);
        i++;
        j++;
      } else if (dp[i + 1][j] >= dp[i][j + 1]) {
        i++;
      } else {
        j++;
      }
    }
    return out;
  }
}
