import 'package:equatable/equatable.dart';

import '../../../core/game/domain/logical_letter.dart';

/// Serializable snapshot of today's board so play survives an app kill.
///
/// Only the submitted guess *words* are stored; on load they are replayed
/// through the engine against today's answer to reconstruct per-tile results
/// and win/lose status — keeping the engine the single source of truth.
/// [outcomeRecorded] guards against double-counting streak/stats/coins when a
/// finished board is restored.
class DailyBoardSnapshot extends Equatable {
  const DailyBoardSnapshot({
    required this.puzzleDate,
    required this.guesses,
    required this.outcomeRecorded,
  });

  final DateTime puzzleDate;
  final List<List<LogicalLetter>> guesses;
  final bool outcomeRecorded;

  DailyBoardSnapshot copyWith({
    List<List<LogicalLetter>>? guesses,
    bool? outcomeRecorded,
  }) => DailyBoardSnapshot(
    puzzleDate: puzzleDate,
    guesses: guesses ?? this.guesses,
    outcomeRecorded: outcomeRecorded ?? this.outcomeRecorded,
  );

  Map<String, dynamic> toJson() => {
    'date': puzzleDate.toIso8601String(),
    'guesses': guesses.map((g) => g.map((l) => l.value).toList()).toList(),
    'recorded': outcomeRecorded,
  };

  factory DailyBoardSnapshot.fromJson(Map<String, dynamic> json) =>
      DailyBoardSnapshot(
        puzzleDate: DateTime.parse(json['date'] as String),
        guesses: (json['guesses'] as List)
            .map(
              (g) => (g as List)
                  .map((v) => LogicalLetter(v as String))
                  .toList(),
            )
            .toList(),
        outcomeRecorded: json['recorded'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [puzzleDate, guesses, outcomeRecorded];
}
