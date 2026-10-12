/// Liang hyphenation (the algorithm used by TeX) driven by TeX pattern files.
class Hyphenator {
  Hyphenator._(
    this._patterns,
    this.minLeft,
    this.minRight,
    this._maxLen,
    this._exceptions,
  );

  /// Parses a hyph-utf8 style TeX source: the `\patterns{...}` block and,
  /// if present, the `\hyphenation{...}` exceptions block.
  ///
  /// No patterns are bundled with this package; load the file for your
  /// language yourself and mind its license.
  factory Hyphenator.fromTex(String src, {int minLeft = 2, int minRight = 2}) {
    String block(String name) {
      final i = src.indexOf('\\$name{');
      if (i < 0) return '';
      final j = src.indexOf('}', i);
      return src.substring(i + name.length + 2, j);
    }

    String strip(String s) => s.split('\n').map((l) {
          final k = l.indexOf('%');
          return k >= 0 ? l.substring(0, k) : l;
        }).join('\n');

    final digit = RegExp(r'[0-9]');
    final ws = RegExp(r'\s+');
    final pats = <String, List<int>>{};
    var maxLen = 0;
    for (final p
        in strip(block('patterns')).split(ws).where((e) => e.isNotEmpty)) {
      final letters = StringBuffer();
      final vals = <int>[];
      var pending = 0;
      var had = false;
      for (final r in p.runes) {
        final c = String.fromCharCode(r);
        if (digit.hasMatch(c)) {
          pending = int.parse(c);
          had = true;
        } else {
          vals.add(had ? pending : 0);
          pending = 0;
          had = false;
          letters.write(c);
        }
      }
      vals.add(had ? pending : 0);
      final k = letters.toString();
      pats[k] = vals;
      if (k.length > maxLen) maxLen = k.length;
    }
    final exc = <String, List<int>>{};
    for (final w
        in strip(block('hyphenation')).split(ws).where((e) => e.isNotEmpty)) {
      final letters = w.replaceAll('-', '');
      final pts = <int>[];
      var n = 0;
      for (final r in w.runes) {
        if (String.fromCharCode(r) == '-') {
          pts.add(n);
        } else {
          n++;
        }
      }
      exc[letters] = pts;
    }
    return Hyphenator._(pats, minLeft, minRight, maxLen, exc);
  }

  final Map<String, List<int>> _patterns;
  final Map<String, List<int>> _exceptions;
  final int _maxLen;
  final _cache = <String, List<int>>{};
  static final _letters = RegExp(r'^\p{L}+$', unicode: true);

  /// Minimum characters before the first hyphen.
  final int minLeft;

  /// Minimum characters after the last hyphen.
  final int minRight;

  /// Number of loaded patterns.
  int get patternCount => _patterns.length;

  /// Character indices of [word] where a hyphen is allowed: a value `i` means
  /// between `word[i - 1]` and `word[i]`. Words with non-letters yield none.
  List<int> points(String word) =>
      _cache.putIfAbsent(word, () => _compute(word));

  List<int> _compute(String word) {
    final w = word.toLowerCase();
    if (w.length < minLeft + minRight || !_letters.hasMatch(w)) {
      return const [];
    }
    final ex = _exceptions[w];
    if (ex != null) {
      return ex.where((p) => p >= minLeft && p <= w.length - minRight).toList();
    }
    final t = '.$w.';
    final n = t.length;
    final v = List<int>.filled(n + 1, 0);
    for (var i = 0; i < n; i++) {
      for (var l = 1; l <= _maxLen && i + l <= n; l++) {
        final vals = _patterns[t.substring(i, i + l)];
        if (vals == null) continue;
        for (var k = 0; k < vals.length; k++) {
          if (vals[k] > v[i + k]) v[i + k] = vals[k];
        }
      }
    }
    final out = <int>[];
    for (var j = minLeft; j <= w.length - minRight; j++) {
      if (v[j + 1].isOdd) out.add(j);
    }
    return out;
  }

  /// Splits [word] at its hyphenation points,
  /// e.g. `"hyphenation"` -> `[hy, phen, ation]`.
  List<String> split(String word) {
    final pts = points(word);
    if (pts.isEmpty) return [word];
    final out = <String>[];
    var s = 0;
    for (final p in pts) {
      out.add(word.substring(s, p));
      s = p;
    }
    out.add(word.substring(s));
    return out;
  }
}
