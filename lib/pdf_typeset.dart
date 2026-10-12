/// Pure Dart typesetting core: optimal paragraph line breaking and
/// pattern-based hyphenation.
///
/// This library has no dependency on `package:pdf` or Flutter.
library;

export 'src/hyphenator.dart' show Hyphenator;
export 'src/line_breaker.dart'
    show
        Box,
        BreakParams,
        BreakResult,
        BrokenLine,
        Glue,
        Item,
        Penalty,
        breakParagraph,
        kInfinitePenalty;
