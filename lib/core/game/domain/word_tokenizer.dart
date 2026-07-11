import 'logical_letter.dart';
import 'uzbek_alphabet.dart';

/// Splits a raw string into logical letters.
///
/// Pipeline: normalize apostrophes → lowercase → greedy longest-match against
/// the compound set. Greedy matching is deliberate — every `oʻ gʻ sh ch ng`
/// digraph collapses to a single tile. Because Uzbek Latin has no standalone
/// `c`/`w`, `c` is always the head of `ch`; `sh`/`ng`/`oʻ`/`gʻ` are treated the
/// same way. The curated dictionary is authored so answers tokenize to exactly
/// the intended letter count.
abstract final class WordTokenizer {
  const WordTokenizer._();

  static List<LogicalLetter> tokenize(String raw) {
    final s = UzbekAlphabet.normalizeApostrophes(raw).trim().toLowerCase();
    final result = <LogicalLetter>[];
    var i = 0;
    while (i < s.length) {
      if (i + 1 < s.length) {
        final pair = s.substring(i, i + 2);
        if (UzbekAlphabet.compounds.contains(pair)) {
          result.add(LogicalLetter(pair));
          i += 2;
          continue;
        }
      }
      final ch = s[i];
      if (ch.trim().isEmpty) {
        i += 1;
        continue; // skip stray whitespace
      }
      result.add(LogicalLetter(ch));
      i += 1;
    }
    return result;
  }

  /// Canonical key for a tokenized word — used as a map/set key for dictionary
  /// membership. Joined with `|` so compound boundaries are unambiguous.
  static String keyOf(List<LogicalLetter> letters) =>
      letters.map((l) => l.value).join('|');
}
