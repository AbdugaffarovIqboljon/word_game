import 'package:flutter_test/flutter_test.dart';
import 'package:word_game/core/game/domain/guess.dart';
import 'package:word_game/core/game/domain/letter_result.dart';
import 'package:word_game/core/game/domain/logical_letter.dart';
import 'package:word_game/features/daily/domain/daily_board_snapshot.dart';

void main() {
  test('snapshot json round-trips (including compound letters and results)', () {
    final snapshot = DailyBoardSnapshot(
      puzzleDate: DateTime.utc(2026, 7, 10),
      guesses: [
        Guess(
          letters: const [
            LogicalLetter('q'),
            LogicalLetter('u'),
            LogicalLetter('y'),
            LogicalLetter('o'),
            LogicalLetter('sh'),
          ],
          results: const [
            LetterResult.correct,
            LetterResult.absent,
            LetterResult.present,
            LetterResult.absent,
            LetterResult.correct,
          ],
        ),
      ],
      outcomeRecorded: true,
    );
    final restored = DailyBoardSnapshot.fromJson(snapshot.toJson());
    expect(restored, snapshot);
    expect(restored.guesses.first.letters.last.value, 'sh');
    expect(restored.guesses.first.results.last, LetterResult.correct);
  });
}
