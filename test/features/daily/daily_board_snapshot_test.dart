import 'package:flutter_test/flutter_test.dart';
import 'package:word_game/core/game/domain/logical_letter.dart';
import 'package:word_game/features/daily/domain/daily_board_snapshot.dart';

void main() {
  test('snapshot json round-trips (including compound letters)', () {
    final snapshot = DailyBoardSnapshot(
      puzzleDate: DateTime.utc(2026, 7, 10),
      guesses: [
        [
          const LogicalLetter('q'),
          const LogicalLetter('u'),
          const LogicalLetter('y'),
          const LogicalLetter('o'),
          const LogicalLetter('sh'),
        ],
      ],
      outcomeRecorded: true,
    );
    final restored = DailyBoardSnapshot.fromJson(snapshot.toJson());
    expect(restored, snapshot);
    expect(restored.guesses.first.last.value, 'sh');
  });
}
