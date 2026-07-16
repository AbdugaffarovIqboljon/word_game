import '../../../core/game/domain/letter_result.dart';

/// Today's puzzle metadata as published by the backend (sizes the board and
/// powers the theme banner) — deliberately never includes the answer word.
class DailyPuzzleMeta {
  const DailyPuzzleMeta({
    required this.puzzleNumber,
    required this.puzzleDate,
    required this.wordLength,
    required this.theme,
    required this.lockedPrefixRaw,
    this.definition,
  });

  final int puzzleNumber;
  final DateTime puzzleDate;
  final int wordLength;
  final String? theme;

  /// The answer's Uzbek gloss for the Lugʻat hint (WS-B: authored to never
  /// contain the answer or its root, so exposing it is safe pre-solve).
  final String? definition;

  /// Raw 1-2 character prefix of the answer (server sends 2 chars so a
  /// compound Uzbek letter, e.g. `oʻ`/`gʻ`, is never truncated); the caller
  /// tokenizes this to get the true first logical letter for the WS4 reveal.
  final String? lockedPrefixRaw;
}

/// Outcome of one server-evaluated guess.
class GuessEvaluation {
  const GuessEvaluation({
    required this.results,
    required this.solved,
    this.answer,
  });

  final List<LetterResult> results;
  final bool solved;

  /// The revealed answer word — present only on a win or when the request set
  /// `revealOnFail`. Callers must display, never persist, this beyond the
  /// session's existing stats/history storage.
  final String? answer;
}

/// Thrown when the backend cannot be reached (offline, timeout, 5xx, or
/// Supabase not configured) — the daily UI must treat this as a retry-able
/// error, never as a wrong guess or a crash.
class DailyPuzzleUnavailableException implements Exception {
  const DailyPuzzleUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'DailyPuzzleUnavailableException: $message';
}

/// Thrown when the server rejects a guess as not a real dictionary word —
/// mirrors the client's own pre-check but is the authoritative source.
class InvalidGuessWordException implements Exception {
  const InvalidGuessWordException();
}

/// Server-authoritative source for the daily puzzle: metadata for sizing and
/// theme, and guess evaluation. Implemented against Supabase in the data
/// layer; the engine/cubit depend only on this interface.
abstract class DailyPuzzleRepository {
  Future<DailyPuzzleMeta> fetchMeta(DateTime puzzleDate);

  Future<GuessEvaluation> evaluateGuess({
    required DateTime puzzleDate,
    required String guess,
    required bool revealOnFail,
  });
}
