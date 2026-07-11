import 'package:equatable/equatable.dart';

import '../../../core/config/game_config.dart';

/// The coin reward for solving the daily, broken into the three lines shown on
/// the share screen's breakdown card (base + speed + streak).
class DailyReward extends Equatable {
  const DailyReward({
    required this.base,
    required this.speed,
    required this.streakBonus,
  });

  final int base;
  final int speed;
  final int streakBonus;

  int get total => base + speed + streakBonus;

  /// Faster solves earn more (fewer attempts used) and longer streaks add a
  /// capped daily bonus. All numbers come from [GameConfig].
  factory DailyReward.forSolve(
    GameConfig config, {
    required int attemptsUsed,
    required int streakAfter,
  }) {
    final remaining = (config.maxAttempts - attemptsUsed).clamp(
      0,
      config.maxAttempts,
    );
    final speed = remaining * config.dailySpeedBonusPerAttempt;
    final streakBonus = (streakAfter * config.dailyStreakBonusPerDay).clamp(
      0,
      config.dailyStreakBonusCap,
    );
    return DailyReward(
      base: config.dailyBaseReward,
      speed: speed,
      streakBonus: streakBonus,
    );
  }

  @override
  List<Object?> get props => [base, speed, streakBonus];
}
