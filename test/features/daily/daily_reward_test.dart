import 'package:flutter_test/flutter_test.dart';
import 'package:word_game/core/config/game_config.dart';
import 'package:word_game/features/daily/domain/daily_reward.dart';

void main() {
  const config = GameConfig();

  test('solve in 4/5 with streak 13', () {
    final r = DailyReward.forSolve(config, attemptsUsed: 4, streakAfter: 13);
    expect(r.base, 40);
    expect(r.speed, 10); // (5-4) * 10
    expect(r.streakBonus, 65); // 13 * 5
    expect(r.total, 115);
  });

  test('solve in 1/5 with no streak', () {
    final r = DailyReward.forSolve(config, attemptsUsed: 1, streakAfter: 0);
    expect(r.speed, 40); // (5-1) * 10
    expect(r.streakBonus, 0);
    expect(r.total, 80);
  });

  test('streak bonus is capped', () {
    final r = DailyReward.forSolve(config, attemptsUsed: 5, streakAfter: 30);
    expect(r.speed, 0);
    expect(r.streakBonus, 100); // 30*5=150 capped at 100
  });
}
