import '../../../core/game/domain/guess.dart';
import '../../../core/game/domain/guess_evaluator.dart';
import '../../../core/game/domain/letter_result.dart';
import '../../../core/game/domain/logical_letter.dart';
import '../../../core/game/domain/word_tokenizer.dart';

/// The fixed script for the guided onboarding tutorial (WS1).
///
/// Independent of the daily dictionary schedule: the hidden answer is KITOB
/// ("book") and the guided first guess is KOBRA. The pair is chosen so the first
/// reveal shows ALL THREE colors — green (K, correct place), amber (O and B,
/// present) and gray (R and A, absent) — which the sequential teach callouts
/// point at.
///
/// WS4: 5 attempts, and the answer's first letter (K) is revealed and locked from
/// the start; the guided guess therefore also begins with K, and the tutorial
/// teaches on a board that already shows the green first letter.
abstract final class TutorialScript {
  const TutorialScript._();

  static const int columns = 5;
  static const int rows = 5;

  /// Hidden answer of the tutorial puzzle.
  static final List<LogicalLetter> answer = WordTokenizer.tokenize('kitob');

  /// The word the user is guided to type first (shares KITOB's locked first K).
  static final List<LogicalLetter> firstGuess = WordTokenizer.tokenize('kobra');

  /// Revealed + locked leading letters — the answer's first letter (WS4).
  static List<LogicalLetter> get lockedPrefix => [answer.first];

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
