import 'dart:async';

import '../../../core/game/domain/dictionary.dart';
import '../../../core/game/domain/guess_evaluator.dart';
import '../../../core/game/domain/letter_result.dart';
import '../../../core/game/domain/logical_letter.dart';
import '../../../core/game/domain/word_tokenizer.dart';
import '../domain/daily_puzzle_repository.dart';

/// Server-primary [DailyPuzzleRepository] with a seamless offline/latency
/// fallback.
///
/// The [_primary] Supabase repository stays authoritative: as long as it answers
/// within [_networkTimeout], its metadata and its server-scored guesses are used
/// unchanged, and a definitive `not_a_word` ([InvalidGuessWordException]) is
/// always honoured (never overridden by the fallback).
///
/// When the primary is unreachable — offline, a timeout beyond [_networkTimeout]
/// (default 2.5s), or any 5xx surfaced as [DailyPuzzleUnavailableException] — we
/// serve the day from the bundled schedule asset instead (via [_bundled], the
/// resident [Dictionary]): metadata is derived locally, and the guess is scored
/// with the *same* [GuessEvaluator] the engine uses, whose two-pass duplicate
/// handling is identical to the `evaluate-guess` Edge Function. So the board is
/// fully playable in airplane mode with no change in UX.
///
/// Dedupe/never-double-score is a property of the caller: each submitted guess is
/// appended once to the persisted board (with the results it was scored with,
/// server or local) and replayed from storage on reload without re-scoring — so a
/// reconnect never re-evaluates a prior attempt regardless of which path scored
/// it.
class FallbackDailyPuzzleRepository implements DailyPuzzleRepository {
  FallbackDailyPuzzleRepository({
    required DailyPuzzleRepository primary,
    required Dictionary bundled,
    Duration networkTimeout = const Duration(milliseconds: 2500),
  })  : _primary = primary,
        _bundled = bundled,
        _networkTimeout = networkTimeout;

  final DailyPuzzleRepository _primary;
  final Dictionary _bundled;
  final Duration _networkTimeout;

  @override
  Future<DailyPuzzleMeta> fetchMeta(DateTime puzzleDate) async {
    try {
      return await _primary.fetchMeta(puzzleDate).timeout(_networkTimeout);
    } catch (_) {
      final meta = _bundledMeta(puzzleDate);
      if (meta == null) {
        throw const DailyPuzzleUnavailableException(
          'offline and no bundled puzzle for this date',
        );
      }
      return meta;
    }
  }

  @override
  Future<GuessEvaluation> evaluateGuess({
    required DateTime puzzleDate,
    required String guess,
    required bool revealOnFail,
  }) async {
    try {
      return await _primary
          .evaluateGuess(
            puzzleDate: puzzleDate,
            guess: guess,
            revealOnFail: revealOnFail,
          )
          .timeout(_networkTimeout);
    } on InvalidGuessWordException {
      // Authoritative server verdict — the guess is genuinely not a word.
      // Never mask it with a local score.
      rethrow;
    } catch (_) {
      return _bundledEvaluate(puzzleDate, guess, revealOnFail: revealOnFail);
    }
  }

  DailyPuzzleMeta? _bundledMeta(DateTime puzzleDate) {
    final answer = _bundled.answerForDate(puzzleDate);
    if (answer.isEmpty) return null;
    return DailyPuzzleMeta(
      puzzleNumber: _bundled.puzzleNumberForDate(puzzleDate),
      puzzleDate: puzzleDate,
      wordLength: answer.length,
      theme: _bundled.themeFor(answer),
      lockedPrefixRaw: _lockedPrefixRaw(answer),
    );
  }

  GuessEvaluation _bundledEvaluate(
    DateTime puzzleDate,
    String guess, {
    required bool revealOnFail,
  }) {
    final answer = _bundled.answerForDate(puzzleDate);
    if (answer.isEmpty) {
      throw const DailyPuzzleUnavailableException(
        'offline and no bundled answer for this date',
      );
    }
    final guessTokens = WordTokenizer.tokenize(guess);
    // Mirror the server's dictionary check against the same bundled word list
    // the instant pre-check uses, so offline "not a word" behaves identically.
    if (guessTokens.length != answer.length || !_bundled.contains(guessTokens)) {
      throw const InvalidGuessWordException();
    }
    final results = GuessEvaluator.evaluate(guessTokens, answer);
    final solved = results.every((r) => r == LetterResult.correct);
    return GuessEvaluation(
      results: results,
      solved: solved,
      answer: (solved || revealOnFail)
          ? answer.map((l) => l.value).join()
          : null,
    );
  }

  /// The 1-2 leading characters of the answer, matching the server's
  /// `left(normalized_word, 2)` (2 chars so a compound `oʻ`/`gʻ`/`sh`/`ch`/`ng`
  /// first letter is never split). The caller re-tokenizes and takes the first
  /// logical letter for the WS4 reveal.
  String _lockedPrefixRaw(List<LogicalLetter> answer) {
    final word = answer.map((l) => l.value).join();
    return word.length <= 2 ? word : word.substring(0, 2);
  }
}
