import 'package:pdf_typeset/pdf_typeset.dart';
import 'package:test/test.dart';

const _fill = Glue(0, double.infinity, 0);
const _forced = Penalty(0, -kInfinitePenalty);

List<Item> _words(int count, {double word = 20, double space = 5}) {
  final items = <Item>[];
  for (var i = 0; i < count; i++) {
    if (i > 0) items.add(Glue(space, space, 0));
    items.add(Box(word, 'w$i'));
  }
  return [...items, _fill, _forced];
}

void main() {
  group('breakParagraph', () {
    test('a paragraph that fits is a single line', () {
      final r = breakParagraph(_words(2), const BreakParams(lineWidth: 200))!;
      expect(r.lines, hasLength(1));
      expect(r.pass, 1);
      expect(r.overfull, 0);
      expect(r.lines.single.start, 0);
      expect(r.lines.single.end, 4);
    });

    test('breaks six words into three lines of two', () {
      // 2 words = 45 pt stretch to 50 (ratio 1); 3 words = 70 pt cannot shrink.
      final r = breakParagraph(_words(6), const BreakParams(lineWidth: 50))!;
      expect(r.pass, 1);
      expect(r.lines.map((l) => (l.start, l.end)).toList(),
          [(0, 3), (4, 7), (8, 12)]);
      expect(r.lines[0].ratio, closeTo(1, 1e-9));
      expect(r.lines.every((l) => !l.hyphenated), isTrue);
    });

    test('uses a hyphen break when the first pass fails', () {
      final items = <Item>[
        const Box(30, 'aaaa'),
        const Glue(5, 3, 1),
        const Box(10, 'hy'),
        const Penalty(5, 50, flagged: true),
        const Box(20, 'phen'),
        _fill,
        _forced,
      ];
      final r = breakParagraph(items, const BreakParams(lineWidth: 50))!;
      expect(r.pass, 2);
      expect(r.lines, hasLength(2));
      expect(r.lines[0].hyphenated, isTrue);
      expect(r.lines[0].end, 3);
      expect(r.lines[1].start, 4);
    });

    test('allowHyphens: false never breaks at flagged penalties', () {
      final items = <Item>[
        const Box(30, 'aaaa'),
        const Glue(5, 3, 1),
        const Box(10, 'hy'),
        const Penalty(5, 50, flagged: true),
        const Box(20, 'phen'),
        _fill,
        _forced,
      ];
      final r = breakParagraph(
        items,
        const BreakParams(lineWidth: 50),
        allowHyphens: false,
      )!;
      expect(r.pass, 3);
      expect(r.lines.any((l) => l.hyphenated), isFalse);
    });

    test('an unbreakable overlong word is reported as overfull', () {
      final items = <Item>[const Box(80, 'long'), _fill, _forced];
      final r = breakParagraph(items, const BreakParams(lineWidth: 50))!;
      expect(r.pass, 3);
      expect(r.overfull, 1);
    });

    test('parshape gives each line its own width', () {
      // First line 45 wide (two words), the rest 100 wide (four words: 95).
      final r = breakParagraph(
        _words(6),
        const BreakParams(parshape: [45, 100]),
      )!;
      expect(r.lines, hasLength(2));
      expect(r.lines.first.end, 3);
    });

    test('lines cover the paragraph without gaps', () {
      final items = _words(40, word: 17, space: 4);
      final r = breakParagraph(items, const BreakParams(lineWidth: 120))!;
      expect(r.lines.first.start, 0);
      expect(r.lines.last.end, items.length - 1);
      for (var i = 1; i < r.lines.length; i++) {
        expect(r.lines[i].start, r.lines[i - 1].end + 1);
      }
      expect(r.overfull, 0);
    });
  });
}
