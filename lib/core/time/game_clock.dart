import '../config/game_config.dart';

/// Resolves the current "puzzle date" and the countdown to the next word.
///
/// The daily word rolls over at **Tashkent midnight** (UTC+5, no DST —
/// [GameConfig.rolloverUtcOffsetHours]). All date math is done in UTC to stay
/// timezone-independent; [now] is injectable so streak/countdown logic is fully
/// testable.
class GameClock {
  GameClock({required GameConfig config, DateTime Function()? now})
    : _config = config,
      _now = now ?? (() => DateTime.now().toUtc());

  final GameConfig _config;
  final DateTime Function() _now;

  Duration get _offset => Duration(hours: _config.rolloverUtcOffsetHours);

  DateTime nowUtc() => _now().toUtc();

  /// The calendar date (in Tashkent time) of the currently-active puzzle,
  /// returned as a date-only UTC instant so it is a stable map/streak key.
  DateTime puzzleDate() {
    final local = nowUtc().add(_offset);
    return DateTime.utc(local.year, local.month, local.day);
  }

  /// Time remaining until the next puzzle unlocks (next Tashkent midnight).
  Duration untilNextRollover() {
    final local = nowUtc().add(_offset);
    final nextLocalMidnight = DateTime.utc(
      local.year,
      local.month,
      local.day,
    ).add(const Duration(days: 1));
    final nextRolloverUtc = nextLocalMidnight.subtract(_offset);
    return nextRolloverUtc.difference(nowUtc());
  }
}
