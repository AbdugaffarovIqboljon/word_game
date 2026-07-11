import 'guess.dart';
import 'letter_result.dart';
import 'logical_letter.dart';

/// Reduces the full guess history to the best-known state per logical letter,
/// for coloring the keyboard.
///
/// Priority is `correct > present > absent` (decisions §7): once a key is known
/// correct it never downgrades, even if a later guess places the same letter in
/// a wrong position. Only letters that have actually been guessed appear in the
/// result; everything else stays in the keyboard's `default` state.
abstract final class KeyboardAggregator {
  const KeyboardAggregator._();

  static Map<LogicalLetter, LetterResult> aggregate(Iterable<Guess> guesses) {
    final best = <LogicalLetter, LetterResult>{};
    for (final guess in guesses) {
      for (var i = 0; i < guess.letters.length; i++) {
        final letter = guess.letters[i];
        final result = guess.results[i];
        final existing = best[letter];
        if (existing == null || result.priority > existing.priority) {
          best[letter] = result;
        }
      }
    }
    return best;
  }
}
