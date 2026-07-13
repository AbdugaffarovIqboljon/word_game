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

/// Cubit-level contract for the Lugʻat (definition) hint (WS1). Shared by
/// DailyCubit and PracticeCubit; testing one covers the atomic pay→show→refund.
void main() {
  const config = GameConfig();
  final clock = GameClock(config: config, now: () => DateTime.utc(2026, 7, 10, 12));

  late PreferencesService prefs;
  late WalletService wallet;

  DailyCubit cubitWith(InMemoryDictionary dict) => DailyCubit(
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

  // Single-entry dictionaries so answerForDate is deterministic.
  final withDef = InMemoryDictionary(
    entries: const [DictionaryEntry('qalam', 'Yozuv quroli')],
  );
  final withoutDef = InMemoryDictionary(
    entries: const [DictionaryEntry('qalam', '')], // empty == no definition
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await PreferencesService.create();
    wallet = WalletService(prefs: prefs)..load();
  });

  test('definition present: pays once, shows the definition, no refund', () async {
    final cubit = cubitWith(withDef);
    await cubit.load();
    expect(cubit.hasDefinition, isTrue);

    var paid = 0, refunded = 0;
    String? shown;
    final ok = await cubit.purchaseDefinition(
      pay: () async {
        paid++;
        return true;
      },
      refund: () async => refunded++,
      reveal: (def) async {
        shown = def;
        return true;
      },
    );

    expect(ok, isTrue);
    expect(paid, 1);
    expect(refunded, 0);
    expect(shown, 'Yozuv quroli');
    await cubit.close();
  });

  test('definition absent: card is unavailable and purchase never charges', () async {
    final cubit = cubitWith(withoutDef);
    await cubit.load();
    expect(cubit.hasDefinition, isFalse); // card hidden (WS1 req b)

    var paid = 0;
    var revealed = false;
    final ok = await cubit.purchaseDefinition(
      pay: () async {
        paid++;
        return true;
      },
      refund: () async {},
      reveal: (_) async {
        revealed = true;
        return true;
      },
    );

    expect(ok, isFalse);
    expect(paid, 0); // no charge on missing data
    expect(revealed, isFalse);
    await cubit.close();
  });

  test('failed payment shows nothing', () async {
    final cubit = cubitWith(withDef);
    await cubit.load();

    var revealed = false;
    final ok = await cubit.purchaseDefinition(
      pay: () async => false,
      refund: () async {},
      reveal: (_) async {
        revealed = true;
        return true;
      },
    );

    expect(ok, isFalse);
    expect(revealed, isFalse); // no effect when payment fails
    await cubit.close();
  });

  test('display failure refunds the charge', () async {
    final cubit = cubitWith(withDef);
    await cubit.load();

    var paid = 0, refunded = 0;
    final ok = await cubit.purchaseDefinition(
      pay: () async {
        paid++;
        return true;
      },
      refund: () async => refunded++,
      reveal: (_) async => false, // dialog could not display
    );

    expect(ok, isFalse);
    expect(paid, 1);
    expect(refunded, 1); // charge never lands without the definition shown
    await cubit.close();
  });
}
