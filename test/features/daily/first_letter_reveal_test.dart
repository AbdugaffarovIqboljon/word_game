import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_game/core/config/game_config.dart';
import 'package:word_game/core/game/data/in_memory_dictionary.dart';
import 'package:word_game/core/game/domain/letter_result.dart';
import 'package:word_game/core/game/domain/logical_letter.dart';
import 'package:word_game/core/storage/preferences_service.dart';
import 'package:word_game/core/time/game_clock.dart';
import 'package:word_game/features/daily/data/daily_board_repository.dart';
import 'package:word_game/features/daily/data/daily_chest_repository.dart';
import 'package:word_game/features/daily/presentation/daily_cubit.dart';
import 'package:word_game/features/daily/presentation/daily_state.dart';
import 'package:word_game/features/stats/data/stats_repository.dart';
import 'package:word_game/features/streak/data/streak_history_repository.dart';
import 'package:word_game/features/streak/data/streak_repository.dart';
import 'package:word_game/features/wallet/data/wallet_service.dart';

/// WS4: first letter revealed + locked, 5 attempts. (DailyCubit and PracticeCubit
/// share the mechanic; testing one covers the engine wiring.)
void main() {
  const config = GameConfig(); // reveal_first_letter defaults to true
  final dict = InMemoryDictionary(
    entries: const [DictionaryEntry('qalam', 'Yozuv quroli')],
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

  const q = LogicalLetter('q');

  test('config defaults: 5 attempts, reveal on', () {
    expect(config.maxAttempts, 5);
    expect(config.revealFirstLetter, isTrue);
  });

  test('board pre-stages the answer first letter and shows it green', () async {
    final cubit = newCubit();
    await cubit.load();

    expect(cubit.lockedPrefix, [q]);
    expect(cubit.input.value, [q]); // row 1 begins on the locked letter
    expect(cubit.state.keyStates[q], LetterResult.correct); // green from the start
    await cubit.close();
  });

  test('the locked first letter cannot be deleted', () async {
    final cubit = newCubit();
    await cubit.load();

    cubit.addLetter(const LogicalLetter('a'));
    expect(cubit.input.value, [q, const LogicalLetter('a')]);
    cubit.removeLetter();
    expect(cubit.input.value, [q]); // back to the locked prefix
    cubit.removeLetter();
    expect(cubit.input.value, [q]); // and no further — the lock holds
    await cubit.close();
  });

  test('only the remaining 4 letters are typed; the guess is green in column 1',
      () async {
    final cubit = newCubit();
    await cubit.load();

    // First letter is locked, so the player types just a-l-a-m to spell qalam.
    for (final l in const [
      LogicalLetter('a'),
      LogicalLetter('l'),
      LogicalLetter('a'),
      LogicalLetter('m'),
    ]) {
      cubit.addLetter(l);
    }
    await cubit.submit();

    expect(cubit.state.phase, DailyPhase.solved);
    final first = cubit.state.guesses.first;
    expect(first.letters.first, q);
    expect(first.results.first, LetterResult.correct); // share grid col 1 = green
    await cubit.close();
  });
}
