import 'letter_result.dart';
import 'logical_letter.dart';

/// Evaluates a guess against the answer using the classic two-pass Wordle rule
/// so duplicate letters resolve correctly.
///
/// Pass 1 marks every exact-position match [LetterResult.correct] and tallies
/// the answer's *remaining* (unmatched) letter counts. Pass 2 walks the
/// non-correct positions left-to-right and marks [LetterResult.present] only
/// while that letter still has remaining count, decrementing as it goes;
/// otherwise [LetterResult.absent]. This is what makes "guess has two of a
/// letter, answer has one" mark exactly one yellow.
abstract final class GuessEvaluator {
  const GuessEvaluator._();

  static List<LetterResult> evaluate(
    List<LogicalLetter> guess,
    List<LogicalLetter> answer,
  ) {
    if (guess.length != answer.length) {
      throw ArgumentError(
        'guess (${guess.length}) and answer (${answer.length}) must be equal length',
      );
    }

    final n = guess.length;
    final results = List<LetterResult>.filled(n, LetterResult.absent);
    final remaining = <String, int>{};

    // Pass 1 — exact matches, tally the rest of the answer.
    for (var i = 0; i < n; i++) {
      if (guess[i] == answer[i]) {
        results[i] = LetterResult.correct;
      } else {
        remaining.update(answer[i].value, (v) => v + 1, ifAbsent: () => 1);
      }
    }

    // Pass 2 — presence against remaining counts.
    for (var i = 0; i < n; i++) {
      if (results[i] == LetterResult.correct) continue;
      final key = guess[i].value;
      final left = remaining[key] ?? 0;
      if (left > 0) {
        results[i] = LetterResult.present;
        remaining[key] = left - 1;
      }
    }

    return results;
  }
}
