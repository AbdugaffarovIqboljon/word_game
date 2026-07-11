import 'package:flutter_test/flutter_test.dart';
import 'package:word_game/core/config/game_config.dart';
import 'package:word_game/features/daily/domain/daily_reward.dart';

void main() {
  const config = GameConfig();

  test('solve in 4/6 with streak 13', () {
    final r = DailyReward.forSolve(config, attemptsUsed: 4, streakAfter: 13);
    expect(r.base, 40);
    expect(r.speed, 20); // (6-4) * 10
    expect(r.streakBonus, 65); // 13 * 5
    expect(r.total, 125);
  });

  test('solve in 1/6 with no streak', () {
    final r = DailyReward.forSolve(config, attemptsUsed: 1, streakAfter: 0);
    expect(r.speed, 50); // (6-1) * 10
    expect(r.streakBonus, 0);
    expect(r.total, 90);
  });

  test('streak bonus is capped', () {
    final r = DailyReward.forSolve(config, attemptsUsed: 6, streakAfter: 30);
    expect(r.speed, 0);
    expect(r.streakBonus, 100); // 30*5=150 capped at 100
  });
}
