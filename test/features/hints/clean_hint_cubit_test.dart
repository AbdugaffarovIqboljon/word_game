import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_game/core/config/game_config.dart';
import 'package:word_game/core/game/data/in_memory_dictionary.dart';
import 'package:word_game/core/game/domain/letter_result.dart';
import 'package:word_game/core/storage/preferences_service.dart';
import 'package:word_game/core/time/game_clock.dart';
import 'package:word_game/features/daily/data/daily_board_repository.dart';
import 'package:word_game/features/daily/data/daily_chest_repository.dart';
import 'package:word_game/features/daily/presentation/daily_cubit.dart';
import 'package:word_game/features/stats/data/stats_repository.dart';
import 'package:word_game/features/streak/data/streak_history_repository.dart';
import 'package:word_game/features/streak/data/streak_repository.dart';
import 'package:word_game/features/wallet/data/wallet_service.dart';

/// Cubit-level contract for the clean-keyboard hint (WS3). Both DailyCubit and
/// PracticeCubit share the same implementation; testing one covers the logic.
void main() {
  const config = GameConfig();
  final dict = InMemoryDictionary(
    entries: const [
      DictionaryEntry('qalam', 'Yozuv quroli'),
      DictionaryEntry('kitob', 'Oʻqish uchun asar'),
    ],
  );
  final clock = GameClock(config: config, now: () => DateTime.utc(2026, 7, 10, 12));

  late PreferencesService prefs;
  late WalletService wallet;

  DailyCubit newCubit() => DailyCubit(
    dictionary: dict,
    clock: clock,
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

  test('normal case grays exactly hintCleanCount absent letters', () async {
    final cubit = newCubit();
    await cubit.load();
    final answerSet = cubit.state.answer.toSet();

    expect(cubit.canCleanKeyboard, isTrue);
    final applied = cubit.cleanKeyboard();
    expect(applied, hasLength(config.hintCleanCount));
    for (final l in applied) {
      expect(answerSet.contains(l), isFalse); // truly absent
      expect(cubit.state.keyStates[l], LetterResult.absent); // visible
    }
    await cubit.close();
  });

  test('idempotency: a second use picks different letters', () async {
    final cubit = newCubit();
    await cubit.load();
    final first = cubit.cleanKeyboard().toSet();
    final second = cubit.cleanKeyboard().toSet();
    expect(first.intersection(second), isEmpty);
    await cubit.close();
  });

  test('atomic success charges once and never refunds', () async {
    final cubit = newCubit();
    await cubit.load();
    var paid = 0;
    var refunded = 0;
    final ok = await cubit.purchaseCleanKeyboard(
      pay: () async {
        paid++;
        return true;
      },
      refund: () async => refunded++,
    );
    expect(ok, isTrue);
    expect(paid, 1);
    expect(refunded, 0);
    await cubit.close();
  });

  test('zero-available: card disabled and purchase never charges', () async {
    final cubit = newCubit();
    await cubit.load();

    // Exhaust every qualifying letter via repeated hints.
    var guard = 0;
    while (cubit.canCleanKeyboard && guard++ < 40) {
      cubit.cleanKeyboard();
    }
    expect(cubit.canCleanKeyboard, isFalse);

    var paid = 0;
    final ok = await cubit.purchaseCleanKeyboard(
      pay: () async {
        paid++;
        return true;
      },
      refund: () async {},
    );
    expect(ok, isFalse);
    expect(paid, 0); // no charge on no effect (req b/c)
    expect(cubit.cleanKeyboard(), isEmpty);
    await cubit.close();
  });

  test('failed payment applies nothing', () async {
    final cubit = newCubit();
    await cubit.load();
    final before = cubit.state.keyStates.length;
    final ok = await cubit.purchaseCleanKeyboard(
      pay: () async => false,
      refund: () async {},
    );
    expect(ok, isFalse);
    expect(cubit.state.keyStates.length, before);
    await cubit.close();
  });
}
