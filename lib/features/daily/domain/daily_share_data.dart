import '../../../core/game/domain/guess.dart';
import 'daily_reward.dart';

/// Everything the Result/Share modal needs, passed via route `extra` so the
/// modal stays decoupled from the daily Cubit. The emoji grid is derived
/// directly from the same per-tile results as the board (component_spec (c)).
class DailyShareData {
  const DailyShareData({
    required this.puzzleNumber,
    required this.attemptsUsed,
    required this.maxAttempts,
    required this.streak,
    required this.guesses,
    required this.solved,
    this.reward,
  });

  final int puzzleNumber;
  final int attemptsUsed;
  final int maxAttempts;
  final int streak;
  final List<Guess> guesses;
  final bool solved;
  final DailyReward? reward;

  /// "4" when solved, "X" when failed — the attempt count for the header line.
  String get attemptsLabel => solved ? '$attemptsUsed' : 'X';

  /// One emoji line per guess row (⬛🟨🟩).
  String get emojiGrid => guesses.map((g) => g.emojiLine).join('\n');
}
