import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_game/core/config/game_config.dart';
import 'package:word_game/core/storage/preferences_service.dart';
import 'package:word_game/core/time/game_clock.dart';
import 'package:word_game/features/daily/data/daily_chest_repository.dart';

/// WS2: the daily chest is claimable exactly once per Tashkent day, and resets at
/// the next Tashkent midnight.
void main() {
  late PreferencesService prefs;
  late DailyChestRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await PreferencesService.create();
    repo = DailyChestRepository(prefs);
  });

  test('claim → same-day blocked → next-day available', () async {
    final today = DateTime.utc(2026, 7, 13);
    final tomorrow = DateTime.utc(2026, 7, 14);

    expect(repo.isReady(today), isTrue); // fresh day: claimable
    await repo.markClaimed(today);

    expect(repo.isClaimed(today), isTrue);
    expect(repo.isReady(today), isFalse); // same day: blocked (no infinite claim)
    expect(repo.isReady(tomorrow), isTrue); // next day: available again
  });

  test('timezone edge: claim just before Tashkent midnight blocks that day only',
      () async {
    const config = GameConfig(); // rollover offset = +5h (Tashkent)
    // 23:30 Tashkent on the 13th == 18:30 UTC.
    final before = GameClock(
      config: config,
      now: () => DateTime.utc(2026, 7, 13, 18, 30),
    );
    // 00:30 Tashkent on the 14th == 19:30 UTC (one hour later, new puzzle day).
    final after = GameClock(
      config: config,
      now: () => DateTime.utc(2026, 7, 13, 19, 30),
    );

    final dayBefore = before.puzzleDate();
    final dayAfter = after.puzzleDate();
    expect(dayBefore, DateTime.utc(2026, 7, 13));
    expect(dayAfter, DateTime.utc(2026, 7, 14)); // rolled over

    await repo.markClaimed(dayBefore);
    expect(repo.isReady(dayBefore), isFalse); // still blocked before midnight
    expect(repo.isReady(dayAfter), isTrue); // reset after midnight
  });

  test('a persisted claim survives a new repository instance (same day)', () async {
    final today = DateTime.utc(2026, 7, 13);
    await repo.markClaimed(today);

    final fresh = DailyChestRepository(prefs);
    expect(fresh.isReady(today), isFalse); // persisted, not just in-memory
  });
}
