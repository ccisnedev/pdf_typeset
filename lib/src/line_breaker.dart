import 'dart:math' as math;

/// Penalty value treated as infinite (TeX uses 10000).
const double kInfinitePenalty = 10000;

/// An element of a paragraph's horizontal list.
sealed class Item {
  const Item();
}

/// Non-stretchable content, such as part of a word.
class Box extends Item {
  /// Creates a box of the given [width]. [text] is optional and carried only
  /// for the caller's convenience.
  const Box(this.width, [this.text = '']);

  /// Width of the box.
  final double width;

  /// Optional text this box represents.
  final String text;
}

/// Stretchable and shrinkable space.
class Glue extends Item {
  /// Creates glue with natural [width], [stretch] and [shrink].
  const Glue(this.width, this.stretch, this.shrink);

  /// Natural width.
  final double width;

  /// Maximum stretch.
  final double stretch;

  /// Maximum shrink.
  final double shrink;
}

/// A potential break point with a cost.
class Penalty extends Item {
  /// Creates a penalty. [width] is added to the line if the break is taken
  /// here (for example the width of a hyphen). [flagged] marks hyphen breaks,
  /// so that consecutive hyphenated lines can be discouraged.
  const Penalty(this.width, this.penalty, {this.flagged = false});

  /// Width added when breaking at this penalty.
  final double width;

  /// Cost of breaking here. [kInfinitePenalty] forbids the break and
  /// `-kInfinitePenalty` forces it.
  final double penalty;

  /// Whether this break is a hyphenation break.
  final bool flagged;
}

/// Tuning parameters. Defaults match plain TeX / LaTeX.
class BreakParams {
  /// Creates parameters. Either [lineWidth] or [parshape] must be set.
  const BreakParams({
    this.lineWidth = 0,
    this.pretolerance = 100,
    this.tolerance = 200,
    this.linePenalty = 10,
    this.adjDemerits = 10000,
    this.doubleHyphenDemerits = 10000,
    this.finalHyphenDemerits = 5000,
    this.parshape,
  });

  /// Width of every line (unless [parshape] is given).
  final double lineWidth;

  /// Per-line widths like TeX's `\parshape`; the last entry repeats.
  final List<double>? parshape;

  /// First pass badness threshold (no hyphenation).
  final double pretolerance;

  /// Second pass badness threshold (with hyphenation).
  final double tolerance;

  /// Extra demerits per line.
  final double linePenalty;

  /// Demerits for adjacent lines with incompatible fitness classes.
  final double adjDemerits;

  /// Demerits for two consecutive hyphenated lines.
  final double doubleHyphenDemerits;

  /// Demerits for a hyphenated last line.
  final double finalHyphenDemerits;

  /// Width of the 1-based [line].
  double widthFor(int line) => parshape == null
      ? lineWidth
      : parshape![(line - 1).clamp(0, parshape!.length - 1)];
}

/// One line of a broken paragraph.
class BrokenLine {
  /// Creates a broken line.
  BrokenLine(this.start, this.end, this.ratio, this.hyphenated, this.badness);

  /// Index of the first item of the line.
  final int start;

  /// Index of the item (glue or penalty) where the line is cut.
  final int end;

  /// Adjustment ratio (TeX glue set): negative shrinks, positive stretches.
  final double ratio;

  /// Whether the line ends with a hyphen break.
  final bool hyphenated;

  /// Badness of the line.
  final double badness;
}

/// Result of [breakParagraph].
class BreakResult {
  /// Creates a result.
  BreakResult(this.lines, this.pass, this.overfull);

  /// The lines, in order.
  final List<BrokenLine> lines;

  /// 1 = no hyphenation, 2 = with hyphenation, 3 = emergency.
  final int pass;

  /// Number of lines that could not shrink enough to fit.
  final int overfull;
}

class _Node {
  _Node(this.pos, this.demerits, this.fitness, this.prev, this.ratio,
      this.flagged, this.badness)
      : line = prev == null ? 0 : prev.line + 1;
  final int line;
  final int pos;
  final double demerits;
  final int fitness;
  final _Node? prev;
  final double ratio;
  final bool flagged;
  final double badness;
  bool alive = true;
}

/// Breaks [items] into lines using the Knuth-Plass algorithm
/// ("Breaking Paragraphs into Lines", 1981).
///
/// [items] must end with `Glue(0, inf, 0)` (the paragraph fill) followed by
/// `Penalty(0, -kInfinitePenalty)`. Like TeX it runs up to three passes:
/// without hyphenation, with hyphenation, and an emergency pass that accepts
/// overfull lines. Returns `null` if no breaking exists.
BreakResult? breakParagraph(
  List<Item> items,
  BreakParams p, {
  bool allowHyphens = true,
}) {
  final r1 = _run(items, p, p.pretolerance, hyphens: false, emergency: false);
  if (r1 != null) return BreakResult(r1.$1, 1, r1.$2);
  if (allowHyphens) {
    final r2 = _run(items, p, p.tolerance, hyphens: true, emergency: false);
    if (r2 != null) return BreakResult(r2.$1, 2, r2.$2);
  }
  final r3 = _run(items, p, 1e9, hyphens: allowHyphens, emergency: true);
  return r3 == null ? null : BreakResult(r3.$1, 3, r3.$2);
}

(List<BrokenLine>, int)? _run(
  List<Item> items,
  BreakParams p,
  double threshold, {
  required bool hyphens,
  required bool emergency,
}) {
  final n = items.length;
  final sw = List<double>.filled(n + 1, 0);
  final sy = List<double>.filled(n + 1, 0);
  final sz = List<double>.filled(n + 1, 0);
  for (var i = 0; i < n; i++) {
    final it = items[i];
    sw[i + 1] = sw[i] +
        (it is Box
            ? it.width
            : it is Glue
                ? it.width
                : 0);
    sy[i + 1] = sy[i] + (it is Glue ? it.stretch : 0);
    sz[i + 1] = sz[i] + (it is Glue ? it.shrink : 0);
  }

  // First non-discardable item after a break at [b].
  int afterBreak(int b) {
    var i = b + 1;
    while (i < n && items[i] is! Box) {
      final it = items[i];
      if (it is Penalty && it.penalty <= -kInfinitePenalty && i > b) break;
      i++;
    }
    return i;
  }

  var active = <_Node>[_Node(-1, 0, 1, null, 0, false, 0)];
  for (var b = 0; b < n; b++) {
    final it = items[b];
    var legal = false;
    if (it is Glue) {
      legal = b > 0 && items[b - 1] is Box;
    } else if (it is Penalty) {
      legal = it.penalty < kInfinitePenalty && (hyphens || !it.flagged);
    }
    if (!legal) continue;
    final pen = it is Penalty ? it.penalty : 0.0;
    final flagged = it is Penalty && it.flagged;
    final penW = it is Penalty ? it.width : 0.0;

    final bestD = List<double>.filled(4, double.infinity);
    final bestN = List<_Node?>.filled(4, null);
    final bestR = List<double>.filled(4, 0);
    final bestB = List<double>.filled(4, 0);
    var minAll = double.infinity;

    final deactivate = <_Node>[];
    for (final a in active) {
      final s = a.pos < 0 ? 0 : afterBreak(a.pos);
      final w = sw[b] - sw[s] + penW;
      final y = sy[b] - sy[s];
      final z = sz[b] - sz[s];
      final lw = p.widthFor(a.line + 1);
      double r;
      if (w < lw) {
        r = y > 0 ? (lw - w) / y : double.infinity;
      } else if (w > lw) {
        r = z > 0 ? (lw - w) / z : double.negativeInfinity;
      } else {
        r = 0;
      }
      if (r < -1 || pen <= -kInfinitePenalty) deactivate.add(a);
      if (r >= -1 && (r <= _maxRatio(threshold) || emergency)) {
        final bad = r.isInfinite ? 1e9 : 100 * math.pow(r.abs(), 3).toDouble();
        if (bad > threshold && !emergency) continue;
        var d = p.linePenalty + bad;
        d = d * d;
        if (pen > 0) {
          d += pen * pen;
        } else if (pen > -kInfinitePenalty) {
          d -= pen * pen;
        }
        if (flagged && a.flagged) d += p.doubleHyphenDemerits;
        if (b == n - 1 && flagged) d += p.finalHyphenDemerits;
        final c = r < -0.5 ? 0 : (r <= 0.5 ? 1 : (r <= 1 ? 2 : 3));
        if ((c - a.fitness).abs() > 1) d += p.adjDemerits;
        d += a.demerits;
        if (d < bestD[c]) {
          bestD[c] = d;
          bestN[c] = a;
          bestR[c] = r;
          bestB[c] = bad;
        }
        if (d < minAll) minAll = d;
      }
    }
    // Emergency pass: when every active node dies, close the line anyway as
    // an overfull line from the least overfull node (TeX makes an overfull box).
    Object? forced;
    if (emergency &&
        deactivate.length == active.length &&
        minAll.isInfinite &&
        active.isNotEmpty) {
      _Node? best;
      var bestOver = double.infinity;
      for (final a in active) {
        final s = a.pos < 0 ? 0 : afterBreak(a.pos);
        final over =
            sw[b] - sw[s] + penW - p.widthFor(a.line + 1) - (sz[b] - sz[s]);
        if (over < bestOver) {
          bestOver = over;
          best = a;
        }
      }
      if (best != null) {
        forced = _Node(b, best.demerits + 1e9, 1, best, double.negativeInfinity,
            flagged, 1e9);
      }
    }
    for (final a in deactivate) {
      a.alive = false;
    }
    active = active.where((a) => a.alive).toList();

    for (var c = 0; c < 4; c++) {
      final d = bestD[c];
      if (d.isInfinite || d > minAll + p.adjDemerits) continue;
      active.add(_Node(b, d, c, bestN[c], bestR[c], flagged, bestB[c]));
    }
    if (forced is _Node) active.add(forced);
    if (active.isEmpty) return null;
    if (b == n - 1) break;
  }

  _Node? best;
  for (final a in active) {
    if (a.pos == n - 1 && (best == null || a.demerits < best.demerits)) {
      best = a;
    }
  }
  if (best == null) return null;
  final lines = <BrokenLine>[];
  var overfull = 0;
  for (_Node? q = best; q != null && q.pos >= 0; q = q.prev) {
    final start =
        q.prev == null || q.prev!.pos < 0 ? 0 : afterBreak(q.prev!.pos);
    if (q.ratio < -1) overfull++;
    lines.add(BrokenLine(start, q.pos, q.ratio, q.flagged, q.badness));
  }
  return (lines.reversed.toList(), overfull);
}

double _maxRatio(double threshold) =>
    math.pow(threshold / 100, 1 / 3).toDouble();
