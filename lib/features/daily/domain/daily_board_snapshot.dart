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
/// finished board is restored. [themeHintShown] guards the theme-hint card's
/// one free auto-show per puzzle — an app restart must never re-show it free.
class DailyBoardSnapshot extends Equatable {
  const DailyBoardSnapshot({
    required this.puzzleDate,
    required this.guesses,
    required this.outcomeRecorded,
    this.themeHintShown = false,
  });

  final DateTime puzzleDate;
  final List<Guess> guesses;
  final bool outcomeRecorded;
  final bool themeHintShown;

  DailyBoardSnapshot copyWith({
    List<Guess>? guesses,
    bool? outcomeRecorded,
    bool? themeHintShown,
  }) => DailyBoardSnapshot(
    puzzleDate: puzzleDate,
    guesses: guesses ?? this.guesses,
    outcomeRecorded: outcomeRecorded ?? this.outcomeRecorded,
    themeHintShown: themeHintShown ?? this.themeHintShown,
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
    'theme_shown': themeHintShown,
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
        themeHintShown: json['theme_shown'] as bool? ?? false,
      );

  @override
  List<Object?> get props =>
      [puzzleDate, guesses, outcomeRecorded, themeHintShown];
}
