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

  test('default distribution is 5 buckets (WS4)', () {
    expect(StatsData().distribution, hasLength(5));
  });

  test('legacy 6-bucket distribution migrates to 5 (row 6 → row 5)', () {
    final legacy = {
      'played': 3,
      'wins': 3,
      'distribution': [0, 1, 0, 0, 1, 1], // row 6 has 1 win
      'lastWinAttempt': 6,
    };
    final s = StatsData.fromJson(legacy);
    expect(s.distribution, hasLength(5));
    expect(s.distribution, [0, 1, 0, 0, 2]); // row 6 merged into row 5
    expect(s.wins, 3); // no wins lost
    expect(s.lastWinAttempt, 5); // 6 clamps onto the new last row
  });
}
