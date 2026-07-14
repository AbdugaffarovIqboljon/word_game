import 'package:equatable/equatable.dart';

import '../../../core/game/domain/guess.dart';
import '../../../core/game/domain/letter_result.dart';
import '../../../core/game/domain/logical_letter.dart';

/// Serializable snapshot of today's board so play survives an app kill.
///
/// Each submitted [Guess] is stored letters *and* results: daily's scoring is
/// server-authoritative (the `evaluate-guess` Edge Function), so results can
/// no longer be recomputed locally on restore — they are simply redrawn.
/// [outcomeRecorded] guards against double-counting streak/stats/coins when a
/// finished board is restored.
class DailyBoardSnapshot extends Equatable {
  const DailyBoardSnapshot({
    required this.puzzleDate,
    required this.guesses,
    required this.outcomeRecorded,
  });

  final DateTime puzzleDate;
  final List<Guess> guesses;
  final bool outcomeRecorded;

  DailyBoardSnapshot copyWith({
    List<Guess>? guesses,
    bool? outcomeRecorded,
  }) => DailyBoardSnapshot(
    puzzleDate: puzzleDate,
    guesses: guesses ?? this.guesses,
    outcomeRecorded: outcomeRecorded ?? this.outcomeRecorded,
  );

  Map<String, dynamic> toJson() => {
    'date': puzzleDate.toIso8601String(),
    'guesses': guesses
        .map(
          (g) => {
            'letters': g.letters.map((l) => l.value).toList(),
            'results': g.results.map((r) => r.name).toList(),
          },
        )
        .toList(),
    'recorded': outcomeRecorded,
  };

  factory DailyBoardSnapshot.fromJson(Map<String, dynamic> json) =>
      DailyBoardSnapshot(
        puzzleDate: DateTime.parse(json['date'] as String),
        guesses: (json['guesses'] as List)
            .map((g) {
              final row = g as Map<String, dynamic>;
              final letters = (row['letters'] as List)
                  .map((v) => LogicalLetter(v as String))
                  .toList();
              final results = (row['results'] as List)
                  .map((v) => LetterResult.values.byName(v as String))
                  .toList();
              return Guess(letters: letters, results: results);
            })
            .toList(),
        outcomeRecorded: json['recorded'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [puzzleDate, guesses, outcomeRecorded];
}
