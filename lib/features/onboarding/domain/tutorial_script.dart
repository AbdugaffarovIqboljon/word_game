import '../../../core/game/domain/guess.dart';
import '../../../core/game/domain/guess_evaluator.dart';
import '../../../core/game/domain/letter_result.dart';
import '../../../core/game/domain/logical_letter.dart';
import '../../../core/game/domain/word_tokenizer.dart';

/// The fixed script for the guided onboarding tutorial (WS1).
///
/// Independent of the daily dictionary schedule: the hidden answer is KITOB
/// ("book") and the guided first guess is OLTIN ("gold"). The pair is chosen so
/// the first reveal shows ALL THREE colors — green (T, correct place), amber
/// (O and I, present) and gray (L and N, absent) — which is exactly what the
/// sequential teach callouts point at.
abstract final class TutorialScript {
  const TutorialScript._();

  static const int columns = 5;
  static const int rows = 6;

  /// Hidden answer of the tutorial puzzle.
  static final List<LogicalLetter> answer = WordTokenizer.tokenize('kitob');

  /// The word the user is guided to type first.
  static final List<LogicalLetter> firstGuess = WordTokenizer.tokenize('oltin');

  /// [firstGuess] evaluated against [answer] — the row that flips in Beat 1.
  static final Guess firstReveal = Guess(
    letters: firstGuess,
    results: GuessEvaluator.evaluate(firstGuess, answer),
  );

  /// Representative tile index for each teach callout (−1 if that color is
  /// somehow absent from the reveal — asserted against in tests).
  static int get correctIndex =>
      firstReveal.results.indexOf(LetterResult.correct);
  static int get presentIndex =>
      firstReveal.results.indexOf(LetterResult.present);
  static int get absentIndex =>
      firstReveal.results.indexOf(LetterResult.absent);

  /// Whether [guess] solves the tutorial puzzle.
  static bool isWin(List<LogicalLetter> guess) =>
      WordTokenizer.keyOf(guess) == WordTokenizer.keyOf(answer);

  /// The answer rendered for the "gentle reveal" on a tutorial loss.
  static String get answerWord => answer.map((l) => l.glyph).join();
}
