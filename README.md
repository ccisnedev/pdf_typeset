# pdf_typeset

Typesetting building blocks in pure Dart, aimed at producing better-looking
PDFs than greedy line filling allows.

> **Status: early preview (0.0.x). The API is unstable and will change.**

## What is in 0.0.1

The pure core only. It has no dependency on `package:pdf` or Flutter, so it
runs on the VM, on the server and in Flutter apps.

- `breakParagraph`: Knuth-Plass optimal line breaking ("Breaking Paragraphs
  into Lines", 1981) over boxes, glue and penalties, with the plain TeX
  defaults (three passes, fitness classes, double-hyphen demerits,
  per-line widths for text that wraps around floats).
- `Hyphenator`: Liang hyphenation (the algorithm used by TeX), loading
  patterns from hyph-utf8 `.tex` files.

You supply the measured widths. Measuring text with a real font and drawing
the resulting lines are outside the core.

## Usage

```dart
import 'package:pdf_typeset/pdf_typeset.dart';

final items = <Item>[
  const Box(30, 'hello'),
  const Glue(5, 2.5, 1.7),
  const Box(10, 'hy'),
  const Penalty(5, 50, flagged: true), // allowed hyphen break
  const Box(20, 'phen'),
  const Glue(0, double.infinity, 0), // paragraph fill
  const Penalty(0, -kInfinitePenalty), // forced final break
];

final result = breakParagraph(items, const BreakParams(lineWidth: 50))!;
for (final line in result.lines) {
  print('items ${line.start}..${line.end}, ratio ${line.ratio}');
}

final hyphenator = Hyphenator.fromTex(patternFileContents);
print(hyphenator.split('hyphenation'));
```

See `example/main.dart` for a complete runnable example.

## Hyphenation patterns and licenses

This package does **not** bundle any pattern files. Pattern sets such as
[hyph-utf8](https://github.com/hyphenation/tex-hyphen) are distributed under
their own licenses (for example the Spanish patterns are MIT/X11); keep their
notices when you ship them with your application.

## Roadmap

- **P1**: core plus a `package:pdf` adapter (`>=3.12.0 <4.0.0`): flow across
  pages (orphans, widows, keep-with-next), footnotes, floats, kerning from
  font tables, PDF/A profiles and deterministic output.
- **P2**: a separate Flutter adapter for previews that share the same core.
- **P3**: font subsetting, tagged structure for PDF/A level "a", stable 1.0 API.

## License

MIT. See [LICENSE](LICENSE).
