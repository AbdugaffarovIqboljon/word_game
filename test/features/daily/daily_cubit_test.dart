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
import 'package:word_game/features/daily/data/fallback_daily_puzzle_repository.dart';
import 'package:word_game/features/daily/domain/daily_puzzle_repository.dart';
import 'package:word_game/features/daily/presentation/daily_cubit.dart';
import 'package:word_game/features/daily/presentation/daily_state.dart';
import 'package:word_game/features/stats/data/stats_repository.dart';
import 'package:word_game/features/streak/data/streak_history_repository.dart';
import 'package:word_game/features/streak/data/streak_repository.dart';
import 'package:word_game/features/wallet/data/wallet_service.dart';

import 'fake_daily_puzzle_repository.dart';

void main() {
  // Reward/streak/restore are orthogonal to the first-letter lock (WS4), so the
  // reveal is turned off here to keep typing full arbitrary words; the lock has
  // its own coverage in first_letter_reveal_test.dart.
  const config = GameConfig(overrides: {'reveal_first_letter': false});
  // Two-word dictionary so the answer and a valid "wrong" guess are both known.
  final dict = InMemoryDictionary(
    entries: const [
      DictionaryEntry('qalam', 'Yozuv quroli'),
      DictionaryEntry('kitob', 'Oʻqish uchun asar'),
    ],
  );
  final clock = GameClock(config: config, now: () => DateTime.utc(2026, 7, 10, 12));

  late PreferencesService prefs;
  late WalletService wallet;

  DailyCubit newCubit({DailyPuzzleRepository? puzzleRepo}) => DailyCubit(
    dictionary: dict,
    puzzleRepo: puzzleRepo ?? FakeDailyPuzzleRepository(dict),
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
  List<LogicalLetter> otherWord() {
    final ans = WordTokenizer.keyOf(answerToday());
    return ans == WordTokenizer.keyOf(WordTokenizer.tokenize('qalam'))
        ? WordTokenizer.tokenize('kitob')
        : WordTokenizer.tokenize('qalam');
  }

  Future<void> typeWord(DailyCubit cubit, List<LogicalLetter> word) async {
    for (final letter in word) {
      cubit.addLetter(letter);
    }
  }

  test('load() starts a fresh playing board', () async {
    final cubit = newCubit();
    await cubit.load();
    expect(cubit.state.phase, DailyPhase.playing);
    expect(cubit.state.guesses, isEmpty);
    expect(cubit.state.puzzleNumber, greaterThan(0));
    await cubit.close();
  });

  test('invalid word bumps the shake signal and does not submit', () async {
    final cubit = newCubit();
    await cubit.load();
    final before = cubit.state.shakeSignal;
    for (final l in WordTokenizer.tokenize('zzzzz')) {
      cubit.addLetter(l);
    }
    await cubit.submit();
    expect(cubit.state.shakeSignal, before + 1);
    expect(cubit.state.invalidWord, isTrue);
    expect(cubit.state.guesses, isEmpty);
    await cubit.close();
  });

  test('a valid wrong guess is recorded and colors the keyboard', () async {
    final cubit = newCubit();
    await cubit.load();
    await typeWord(cubit, otherWord());
    await cubit.submit();
    expect(cubit.state.guesses, hasLength(1));
    expect(cubit.state.phase, DailyPhase.playing);
    expect(cubit.state.keyStates, isNotEmpty);
    await cubit.close();
  });

  test('winning credits coins, bumps streak & stats, and persists', () async {
    final cubit = newCubit();
    await cubit.load();
    await typeWord(cubit, answerToday());
    await cubit.submit(); // awaits reveal delay + outcome

    expect(cubit.state.phase, DailyPhase.solved);
    expect(cubit.state.streak, 1);
    final reward = cubit.state.reward!;
    // solved in 1/5, streak→1: 40 base + 40 speed ((5-1)×10) + 5 streak = 85
    expect(reward.total, 85);
    expect(wallet.coinBalance, 85);
    expect(StreakRepository(prefs).load().current, 1);
    expect(StatsRepository(prefs).load().wins, 1);
    await cubit.close();
  });

  test('restoring a finished board does not double-credit', () async {
    final first = newCubit();
    await first.load();
    await typeWord(first, answerToday());
    await first.submit();
    await first.close();
    expect(wallet.coinBalance, 85);

    // New cubit, same storage/wallet → restore.
    final second = newCubit();
    await second.load();
    expect(second.state.phase, DailyPhase.solved);
    expect(wallet.coinBalance, 85); // not doubled
    expect(second.state.guesses, hasLength(1));
    await second.close();
  });

  test('a mid-game board survives a restart', () async {
    final first = newCubit();
    await first.load();
    await typeWord(first, otherWord());
    await first.submit();
    await first.close();

    final second = newCubit();
    await second.load();
    expect(second.state.phase, DailyPhase.playing);
    expect(second.state.guesses, hasLength(1));
    await second.close();
  });

  test('start online, go offline mid-game, finish — no loss or double-score',
      () async {
    final primary = _FlakyPrimary(FakeDailyPuzzleRepository(dict));
    DailyCubit build() => newCubit(
          puzzleRepo: FallbackDailyPuzzleRepository(
            primary: primary,
            bundled: dict,
            networkTimeout: const Duration(milliseconds: 200),
          ),
        );

    final cubit = build();
    await cubit.load(); // online
    expect(cubit.state.phase, DailyPhase.playing);

    // Online: one wrong guess, scored by the server.
    await typeWord(cubit, otherWord());
    await cubit.submit();
    expect(cubit.state.guesses, hasLength(1));
    expect(primary.evalCalls, 1);

    // Connection drops mid-game.
    primary.online = false;

    // Offline: the winning guess is scored locally against the bundled answer.
    await typeWord(cubit, answerToday());
    await cubit.submit(); // awaits reveal + outcome
    expect(cubit.state.phase, DailyPhase.solved);
    expect(cubit.state.streak, 1);
    expect(cubit.state.guesses, hasLength(2));
    expect(wallet.coinBalance, greaterThan(0));
    final credited = wallet.coinBalance;
    await cubit.close();

    // Reconnect + relaunch: the finished board is replayed from storage, never
    // re-scored or re-credited (dedupe by persisted attempt list).
    primary.online = true;
    final second = build();
    await second.load();
    expect(second.state.phase, DailyPhase.solved);
    expect(second.state.guesses, hasLength(2));
    expect(wallet.coinBalance, credited);
    await second.close();
  });
}

/// Online-toggleable primary: healthy until [online] is cleared, then every call
/// fails like an offline/5xx server so the fallback path engages.
class _FlakyPrimary implements DailyPuzzleRepository {
  _FlakyPrimary(this._inner);

  final DailyPuzzleRepository _inner;
  bool online = true;
  int evalCalls = 0;

  @override
  Future<DailyPuzzleMeta> fetchMeta(DateTime puzzleDate) {
    if (!online) throw const DailyPuzzleUnavailableException('offline');
    return _inner.fetchMeta(puzzleDate);
  }

  @override
  Future<GuessEvaluation> evaluateGuess({
    required DateTime puzzleDate,
    required String guess,
    required bool revealOnFail,
  }) {
    evalCalls++;
    if (!online) throw const DailyPuzzleUnavailableException('offline');
    return _inner.evaluateGuess(
      puzzleDate: puzzleDate,
      guess: guess,
      revealOnFail: revealOnFail,
    );
  }
}
