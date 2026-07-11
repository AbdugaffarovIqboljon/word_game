import 'package:flutter_test/flutter_test.dart';
import 'package:word_game/core/config/game_config.dart';
import 'package:word_game/core/time/game_clock.dart';

void main() {
  const config = GameConfig(); // rollover offset = +5h (Tashkent)

  GameClock clockAt(DateTime utc) => GameClock(config: config, now: () => utc);

  group('GameClock puzzle date (Tashkent midnight rollover)', () {
    test('before local midnight → still same day', () {
      // 18:00 UTC = 23:00 Tashkent, 10 Jul.
      final clock = clockAt(DateTime.utc(2026, 7, 10, 18));
      expect(clock.puzzleDate(), DateTime.utc(2026, 7, 10));
    });

    test('at local midnight → next day', () {
      // 19:00 UTC = 00:00 Tashkent, 11 Jul.
      final clock = clockAt(DateTime.utc(2026, 7, 10, 19));
      expect(clock.puzzleDate(), DateTime.utc(2026, 7, 11));
    });

    test('just before local midnight (UTC day already flipped) stays correct', () {
      // 23:30 UTC = 04:30 Tashkent next day.
      final clock = clockAt(DateTime.utc(2026, 7, 10, 23, 30));
      expect(clock.puzzleDate(), DateTime.utc(2026, 7, 11));
    });
  });

  group('GameClock countdown', () {
    test('one hour before rollover', () {
      final clock = clockAt(DateTime.utc(2026, 7, 10, 18));
      expect(clock.untilNextRollover(), const Duration(hours: 1));
    });

    test('a full day at the moment of rollover', () {
      final clock = clockAt(DateTime.utc(2026, 7, 10, 19));
      expect(clock.untilNextRollover(), const Duration(hours: 24));
    });
  });
}
