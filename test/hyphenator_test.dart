import 'package:pdf_typeset/pdf_typeset.dart';
import 'package:test/test.dart';

const _tex = r'''
% a tiny pattern file for tests
\patterns{
hy3phen
n1a
}
\hyphenation{
ta-ble
}
''';

void main() {
  final hy = Hyphenator.fromTex(_tex);

  test('loads patterns', () {
    expect(hy.patternCount, 2);
  });

  test('applies Liang patterns', () {
    expect(hy.points('hyphenation'), [2, 6]);
    expect(hy.split('hyphenation'), ['hy', 'phen', 'ation']);
  });

  test('is case insensitive and keeps the original casing in splits', () {
    expect(hy.split('Hyphenation'), ['Hy', 'phen', 'ation']);
  });

  test('exceptions override patterns', () {
    expect(hy.points('table'), [2]);
  });

  test('respects minLeft and minRight', () {
    final strict = Hyphenator.fromTex(_tex, minLeft: 3, minRight: 3);
    expect(strict.points('hyphenation'), [6]);
    expect(hy.points('hy'), isEmpty);
  });

  test('words with non-letters are not hyphenated', () {
    expect(hy.points('hyphen-ation'), isEmpty);
    expect(hy.points('hyphen4'), isEmpty);
  });

  test('works with non-ASCII letters', () {
    final h = Hyphenator.fromTex(r'\patterns{ a1ñ }');
    expect(h.split('caña'), ['ca', 'ña']);
  });
}
