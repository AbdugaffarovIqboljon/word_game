import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_game/core/config/game_config.dart';
import 'package:word_game/core/game/data/in_memory_dictionary.dart';
import 'package:word_game/core/storage/preferences_service.dart';
import 'package:word_game/core/time/game_clock.dart';
import 'package:word_game/features/daily/data/daily_board_repository.dart';
import 'package:word_game/features/daily/data/daily_chest_repository.dart';
import 'package:word_game/features/daily/presentation/daily_cubit.dart';
import 'package:word_game/features/stats/data/stats_repository.dart';
import 'package:word_game/features/streak/data/streak_history_repository.dart';
import 'package:word_game/features/streak/data/streak_repository.dart';
import 'package:word_game/features/wallet/data/wallet_service.dart';

import 'fake_daily_puzzle_repository.dart';

/// Mystery theme hint (🔮 Mavzu) — WS-D unit coverage:
///   * one free auto-show per puzzle, persisted with the board snapshot;
///   * atomic pay→show→refund for the paid re-expand;
///   * RC kill-switch `hint_theme_enabled`;
///   * offline theme parity lives in fallback_daily_puzzle_repository_test.
void main() {
  final dict = InMemoryDictionary(
    entries: const [
      DictionaryEntry('qalam', 'Yozuv quroli', 'Asbob'),
      DictionaryEntry('kitob', 'Oʻqish uchun asar', 'Ilm'),
    ],
  );

  late PreferencesService prefs;
  late WalletService wallet;

  DailyCubit newCubit({GameConfig config = const GameConfig()}) => DailyCubit(
    dictionary: dict,
    puzzleRepo: FakeDailyPuzzleRepository(dict),
    clock: GameClock(config: config, now: () => DateTime.utc(2026, 7, 10, 12)),
    config: config,
    boardRepo: DailyBoardRepository(prefs),
    chestRepo: DailyChestRepository(prefs),
    streakRepo: StreakRepository(prefs),
    historyRepo: StreakHistoryRepository(prefs),
    statsRepo: StatsRepository(prefs),
    wallet: wallet,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await PreferencesService.create();
    wallet = WalletService(prefs: prefs)..load();
  });

  group('free auto-show persistence', () {
    test('first load owes the free show; marking it persists', () async {
      final cubit = newCubit();
      await cubit.load();
      expect(cubit.state.theme, isNotNull);
      expect(cubit.themeHintAlreadyShown, isFalse);

      await cubit.markThemeHintShown();
      expect(cubit.themeHintAlreadyShown, isTrue);
      await cubit.close();
    });

    test('an app restart never re-shows the free card', () async {
      final first = newCubit();
      await first.load();
      await first.markThemeHintShown();
      await first.close();

      // Same prefs = same persisted board snapshot, fresh cubit = "restart".
      final second = newCubit();
      await second.load();
      expect(second.themeHintAlreadyShown, isTrue);
      await second.close();
    });

    test('marking twice is idempotent', () async {
      final cubit = newCubit();
      await cubit.load();
      await cubit.markThemeHintShown();
      await cubit.markThemeHintShown();
      expect(cubit.themeHintAlreadyShown, isTrue);
      await cubit.close();
    });
  });

  group('paid re-expand (atomic pay → show → refund)', () {
    test('charges coins and shows on the happy path', () async {
      await wallet.creditCoins(100, reason: 'seed');
      final cubit = newCubit();
      await cubit.load();

      var shown = 0;
      final ok = await cubit.purchaseThemeReexpand(
        pay: () => wallet.debitCoins(25, reason: 'test'),
        refund: () async => fail('refund must not run on success'),
        show: () async {
          shown++;
          return true;
        },
      );
      expect(ok, isTrue);
      expect(shown, 1);
      expect(wallet.coinBalance, 75);
      await cubit.close();
    });

    test('failed pay (insufficient coins) never shows', () async {
      final cubit = newCubit();
      await cubit.load();

      final ok = await cubit.purchaseThemeReexpand(
        pay: () => wallet.debitCoins(25, reason: 'test'), // balance 0 → false
        refund: () async {},
        show: () async => fail('show must not run when pay fails'),
      );
      expect(ok, isFalse);
      expect(wallet.coinBalance, 0);
      await cubit.close();
    });

    test('refunds when the card cannot be shown', () async {
      await wallet.creditCoins(100, reason: 'seed');
      final cubit = newCubit();
      await cubit.load();

      final ok = await cubit.purchaseThemeReexpand(
        pay: () => wallet.debitCoins(25, reason: 'test'),
        refund: () => wallet.creditCoins(25, reason: 'refund'),
        show: () async => false, // widget gone — effect failed
      );
      expect(ok, isFalse);
      expect(wallet.coinBalance, 100); // charge fully refunded
      await cubit.close();
    });
  });

  group('RC kill-switch (hint_theme_enabled)', () {
    test('disabled → theme never reaches state, purchases refuse', () async {
      const config = GameConfig(overrides: {'hint_theme_enabled': 0});
      final cubit = newCubit(config: config);
      await cubit.load();
      expect(cubit.state.theme, isNull);

      final ok = await cubit.purchaseThemeReexpand(
        pay: () async => fail('must not charge when the surface is disabled'),
        refund: () async {},
        show: () async => true,
      );
      expect(ok, isFalse);
      await cubit.close();
    });

    test('enabled (default) → theme flows through', () async {
      final cubit = newCubit();
      await cubit.load();
      expect(cubit.state.theme, isNotNull);
      await cubit.close();
    });
  });

  group('daily Lugʻat (definition from puzzle meta)', () {
    test('definition is available and purchase is atomic', () async {
      await wallet.creditCoins(100, reason: 'seed');
      final cubit = newCubit();
      await cubit.load();
      expect(cubit.hasDefinition, isTrue);

      String? revealed;
      final ok = await cubit.purchaseDefinition(
        pay: () => wallet.debitCoins(75, reason: 'test'),
        refund: () => wallet.creditCoins(75, reason: 'refund'),
        reveal: (def) async {
          revealed = def;
          return true;
        },
      );
      expect(ok, isTrue);
      expect(revealed, isNotEmpty);
      expect(wallet.coinBalance, 25);
      await cubit.close();
    });
  });
}
