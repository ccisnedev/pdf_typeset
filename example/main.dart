import 'package:pdf_typeset/pdf_typeset.dart';

// Fixed-pitch "font": every character is 5 units wide.
const _char = 5.0;
const _space = Glue(5, 2.5, 1.7);

void main() {
  // Tiny pattern set, just for the demo. Load real hyph-utf8 files with
  // Hyphenator.fromTex(File('hyph-en-us.tex').readAsStringSync()).
  final hyphenator = Hyphenator.fromTex(r'''
\patterns{ hy3phen n1a 1ty }
''');

  const text = 'Optimal line breaking with hyphenation makes ragged '
      'paragraphs look even and calm';
  final words = text.split(' ');

  final items = <Item>[];
  for (var i = 0; i < words.length; i++) {
    if (i > 0) items.add(_space);
    final syllables = hyphenator.split(words[i]);
    for (var s = 0; s < syllables.length; s++) {
      if (s > 0) items.add(const Penalty(_char, 50, flagged: true));
      items.add(Box(syllables[s].length * _char, syllables[s]));
    }
  }
  items
    ..add(const Glue(0, double.infinity, 0))
    ..add(const Penalty(0, -kInfinitePenalty));

  final result = breakParagraph(items, const BreakParams(lineWidth: 150))!;

  for (final line in result.lines) {
    final buf = StringBuffer();
    for (var i = line.start; i < line.end; i++) {
      final it = items[i];
      if (it is Box) buf.write(it.text);
      if (it is Glue) buf.write(' ');
    }
    if (line.hyphenated) buf.write('-');
    print(
        '${buf.toString().padRight(30)} ratio ${line.ratio.toStringAsFixed(2)}');
  }
}
