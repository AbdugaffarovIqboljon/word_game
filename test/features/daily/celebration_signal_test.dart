import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_game/core/config/game_config.dart';
import 'package:word_game/core/game/data/in_memory_dictionary.dart';
import 'package:word_game/core/game/domain/logical_letter.dart';
import 'package:word_game/core/game/domain/word_tokenizer.dart';
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

import 'fake_daily_puzzle_repository.dart';

/// WS5 — the confetti trigger is an explicit one-shot state-machine event
/// (`celebrateSignal`), not something the UI infers from a phase transition. A
/// fresh win bumps it exactly once; a restored/already-solved board never does,
/// so relaunching a solved day re-fires nothing.
void main() {
  const config = GameConfig(overrides: {'reveal_first_letter': false});
  final dict = InMemoryDictionary(
    entries: const [
      DictionaryEntry('qalam', 'Yozuv quroli'),
      DictionaryEntry('kitob', 'Oʻqish uchun asar'),
    ],
  );
  final clock =
      GameClock(config: config, now: () => DateTime.utc(2026, 7, 10, 12));

  late PreferencesService prefs;
  late WalletService wallet;

  DailyCubit newCubit() => DailyCubit(
        dictionary: dict,
        puzzleRepo: FakeDailyPuzzleRepository(dict),
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

  List<LogicalLetter> answerToday() => dict.answerForDate(clock.puzzleDate());
  List<LogicalLetter> otherWord() =>
      answerToday().map((l) => l.value).join() == 'qalam'
          ? WordTokenizer.tokenize('kitob')
          : WordTokenizer.tokenize('qalam');

  Future<void> type(DailyCubit c, List<LogicalLetter> word) async {
    for (final l in word) {
      c.addLetter(l);
    }
  }

  test('a fresh win bumps the celebration signal exactly once', () async {
    final cubit = newCubit();
    await cubit.load();
    expect(cubit.state.celebrateSignal, 0);

    await type(cubit, answerToday());
    await cubit.submit();

    expect(cubit.state.phase, DailyPhase.solved);
    expect(cubit.state.celebrateSignal, 1);
    await cubit.close();
  });

  test('restoring a solved board never bumps the signal (no re-fire)', () async {
    final first = newCubit();
    await first.load();
    await type(first, answerToday());
    await first.submit();
    expect(first.state.celebrateSignal, 1);
    await first.close();

    // Relaunch: same storage, fresh cubit → restore path in load().
    final second = newCubit();
    await second.load();
    expect(second.state.phase, DailyPhase.solved);
    expect(second.state.celebrateSignal, 0); // restore fires nothing
    await second.close();
  });

  test('a wrong (non-winning) guess does not bump the signal', () async {
    final cubit = newCubit();
    await cubit.load();
    await type(cubit, otherWord()); // a valid word that isn't today's answer
    await cubit.submit();

    expect(cubit.state.phase, DailyPhase.playing);
    expect(cubit.state.celebrateSignal, 0);
    await cubit.close();
  });
}
