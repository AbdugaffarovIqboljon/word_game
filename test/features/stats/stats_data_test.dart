import 'package:flutter_test/flutter_test.dart';
import 'package:word_game/features/stats/domain/stats_data.dart';

void main() {
  test('recordWin updates played/wins/distribution/lastWinAttempt', () {
    final s = StatsData().recordWin(4);
    expect(s.played, 1);
    expect(s.wins, 1);
    expect(s.distribution[3], 1);
    expect(s.lastWinAttempt, 4);
    expect(s.winRatePercent, 100);
  });

  test('recordLoss increases played only', () {
    final s = StatsData().recordWin(4).recordLoss();
    expect(s.played, 2);
    expect(s.wins, 1);
    expect(s.winRatePercent, 50);
  });

  test('json round-trip', () {
    final s = StatsData().recordWin(3).recordWin(5);
    final restored = StatsData.fromJson(s.toJson());
    expect(restored, s);
  });
}
