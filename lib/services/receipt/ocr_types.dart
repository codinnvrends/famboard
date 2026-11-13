/// One piece of recognised text and where it sits on the image, as an OCR
/// engine returns it. ML Kit usually returns one fragment per column (item
/// name, quantity, rate and amount separately), so rows have to be rebuilt.
class OcrFragment {
  const OcrFragment(this.text, this.left, this.top, this.right, this.bottom);

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get cx => (left + right) / 2;
  double get cy => (top + bottom) / 2;
  double get height => bottom - top;
  double get width => right - left;

  factory OcrFragment.fromJson(Map<String, Object?> j) => OcrFragment(
        j['text']! as String,
        (j['l']! as num).toDouble(),
        (j['t']! as num).toDouble(),
        (j['r']! as num).toDouble(),
        (j['b']! as num).toDouble(),
      );

  @override
  String toString() => 'OcrFragment("$text" @${left.round()},${top.round()})';
}

/// OCR output for one photo.
class OcrPage {
  const OcrPage(this.fragments, {this.width = 0, this.height = 0});

  final List<OcrFragment> fragments;
  final double width;
  final double height;

  factory OcrPage.fromJson(Map<String, Object?> j) => OcrPage(
        [for (final l in j['lines']! as List) OcrFragment.fromJson(Map<String, Object?>.from(l! as Map))],
        width: (j['width'] as num?)?.toDouble() ?? 0,
        height: (j['height'] as num?)?.toDouble() ?? 0,
      );
}
