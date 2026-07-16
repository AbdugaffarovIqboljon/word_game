import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/game/domain/letter_result.dart';
import '../domain/daily_puzzle_repository.dart';

/// Supabase-backed [DailyPuzzleRepository].
///
/// Metadata comes from the `daily_puzzle_public` view, which is RLS/grant-
/// restricted at the database to exactly these columns (no answer). Guess
/// scoring is delegated entirely to the `evaluate-guess` Edge Function, which
/// alone holds the service-role key needed to read the real answer — this
/// client only ever sees a per-letter result and, on win/final-reveal, the
/// plaintext word in the response.
class SupabaseDailyPuzzleRepository implements DailyPuzzleRepository {
  const SupabaseDailyPuzzleRepository(this._client);

  /// Null when Supabase never initialized (missing config) — every call then
  /// fails fast with [DailyPuzzleUnavailableException] rather than touching a
  /// live client.
  final SupabaseClient? _client;

  @override
  Future<DailyPuzzleMeta> fetchMeta(DateTime puzzleDate) async {
    final client = _client;
    if (client == null) {
      throw const DailyPuzzleUnavailableException('Supabase not configured');
    }
    final Map<String, dynamic> row;
    try {
      row = await client
          .from('daily_puzzle_public')
          .select('puzzle_number, puzzle_date, word_length, theme, '
              'locked_prefix_raw, definition_uz')
          .eq('puzzle_date', _dateKey(puzzleDate))
          .single();
    } catch (e) {
      throw DailyPuzzleUnavailableException('fetchMeta failed: $e');
    }
    return DailyPuzzleMeta(
      puzzleNumber: row['puzzle_number'] as int,
      puzzleDate: puzzleDate,
      wordLength: row['word_length'] as int,
      theme: row['theme'] as String?,
      lockedPrefixRaw: row['locked_prefix_raw'] as String?,
      definition: row['definition_uz'] as String?,
    );
  }

  @override
  Future<GuessEvaluation> evaluateGuess({
    required DateTime puzzleDate,
    required String guess,
    required bool revealOnFail,
  }) async {
    final client = _client;
    if (client == null) {
      throw const DailyPuzzleUnavailableException('Supabase not configured');
    }

    final FunctionResponse response;
    try {
      response = await client.functions.invoke(
        'evaluate-guess',
        body: {
          'puzzle_date': _dateKey(puzzleDate),
          'guess': guess,
          'reveal_on_fail': revealOnFail,
        },
      );
    } catch (e) {
      throw DailyPuzzleUnavailableException('evaluate-guess failed: $e');
    }

    final data = response.data;
    if (data is! Map) {
      throw const DailyPuzzleUnavailableException(
        'evaluate-guess returned malformed data',
      );
    }
    if (data['error'] == 'not_a_word') {
      throw const InvalidGuessWordException();
    }
    if (data['error'] != null) {
      throw DailyPuzzleUnavailableException(
        'evaluate-guess error: ${data['error']}',
      );
    }

    final results = (data['results'] as List)
        .map((r) => LetterResult.values.byName(r as String))
        .toList();
    return GuessEvaluation(
      results: results,
      solved: data['solved'] as bool? ?? false,
      answer: data['answer'] as String?,
    );
  }

  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
