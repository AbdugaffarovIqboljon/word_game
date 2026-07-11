import 'logical_letter.dart';

/// The 29-letter Uzbek Latin alphabet as used by the game (no C, no W — those
/// only appear inside the compounds `ch`/none). Ordering mirrors the on-screen
/// keyboard (`component_spec.md` (a)).
abstract final class UzbekAlphabet {
  const UzbekAlphabet._();

  /// MODIFIER LETTER TURNED COMMA (U+02BB) — the canonical apostrophe used in
  /// `oʻ`/`gʻ`. Every apostrophe-like input is normalized to this.
  static const String turnedComma = 'ʻ';

  /// The five compound letters, canonical form.
  static const Set<String> compounds = {'oʻ', 'gʻ', 'sh', 'ch', 'ng'};

  /// All 29 logical letters in keyboard order (row 1, row 2, row 3 letters).
  static const List<String> _ordered = [
    'q', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', 'oʻ', //
    'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'gʻ', //
    'z', 'x', 'v', 'b', 'n', 'm', 'sh', 'ch', 'ng', //
  ];

  static final List<LogicalLetter> letters =
      _ordered.map(LogicalLetter.new).toList(growable: false);

  static final Set<String> _valueSet = _ordered.toSet();

  /// Apostrophe-like characters that all normalize to [turnedComma].
  static const List<String> _apostropheVariants = [
    "'", // U+0027 APOSTROPHE
    '’', // ’ RIGHT SINGLE QUOTATION MARK
    '‘', // ‘ LEFT SINGLE QUOTATION MARK
    '`', // ` GRAVE ACCENT
    '´', // ´ ACUTE ACCENT
    'ʼ', // ʼ MODIFIER LETTER APOSTROPHE
    '′', // ′ PRIME
  ];

  /// Replaces every apostrophe-variant in [input] with U+02BB. Idempotent.
  static String normalizeApostrophes(String input) {
    var out = input;
    for (final variant in _apostropheVariants) {
      out = out.replaceAll(variant, turnedComma);
    }
    return out;
  }

  /// Whether [value] (canonical form) is one of the 29 letters.
  static bool isLetter(String value) => _valueSet.contains(value);
}
