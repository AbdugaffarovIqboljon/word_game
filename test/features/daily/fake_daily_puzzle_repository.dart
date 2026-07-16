import 'package:word_game/core/game/domain/dictionary.dart';
import 'package:word_game/core/game/domain/guess_evaluator.dart';
import 'package:word_game/core/game/domain/letter_result.dart';
import 'package:word_game/core/game/domain/word_tokenizer.dart';
import 'package:word_game/features/daily/domain/daily_puzzle_repository.dart';

/// Test double standing in for the real `evaluate-guess` Edge Function and
/// `daily_puzzle_public` view: evaluates locally against [dictionary]'s
/// answer for the date, mirroring exactly what the server does, so
/// DailyCubit's orchestration (streak/stats/wallet/restore/WS4 lock) can be
/// exercised deterministically without a network call.
class FakeDailyPuzzleRepository implements DailyPuzzleRepository {
  FakeDailyPuzzleRepository(this.dictionary);

  final Dictionary dictionary;

  @override
  Future<DailyPuzzleMeta> fetchMeta(DateTime puzzleDate) async {
    final answer = dictionary.answerForDate(puzzleDate);
    final raw = answer.map((l) => l.value).join();
    return DailyPuzzleMeta(
      puzzleNumber: dictionary.puzzleNumberForDate(puzzleDate),
      puzzleDate: puzzleDate,
      wordLength: answer.length,
      theme: dictionary.themeFor(answer),
      lockedPrefixRaw: raw.length >= 2 ? raw.substring(0, 2) : raw,
      definition: dictionary.definitionFor(answer),
    );
  }

  @override
  Future<GuessEvaluation> evaluateGuess({
    required DateTime puzzleDate,
    required String guess,
    required bool revealOnFail,
  }) async {
    final answer = dictionary.answerForDate(puzzleDate);
    final results = GuessEvaluator.evaluate(WordTokenizer.tokenize(guess), answer);
    final solved = results.every((r) => r == LetterResult.correct);
    return GuessEvaluation(
      results: results,
      solved: solved,
      answer: (solved || revealOnFail) ? answer.map((l) => l.value).join() : null,
    );
  }
}
