import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_game/core/config/game_config.dart';
import 'package:word_game/core/game/data/in_memory_dictionary.dart';
import 'package:word_game/core/game/domain/word_tokenizer.dart';
import 'package:word_game/core/storage/preferences_service.dart';
import 'package:word_game/features/bonus/data/bonus_played_repository.dart';
import 'package:word_game/features/bonus/presentation/bonus_cubit.dart';
import 'package:word_game/features/bonus/presentation/bonus_state.dart';
import 'package:word_game/features/stats/data/stats_repository.dart';
import 'package:word_game/features/streak/data/streak_repository.dart';
import 'package:word_game/features/streak/domain/streak_calculator.dart';
import 'package:word_game/features/wallet/data/wallet_service.dart';

/// WS3 bonus rounds: coins are granted, bonus-only stats are tallied, played
/// words never repeat, and the streak / daily stats are never touched.
void main() {
  const config = GameConfig();
  final qalam = WordTokenizer.tokenize('qalam');
  final kitob = WordTokenizer.tokenize('kitob');
  final dict = InMemoryDictionary(
    entries: const [
      DictionaryEntry('qalam', 'Yozuv quroli'),
      DictionaryEntry('kitob', 'Oʻqish uchun asar'),
    ],
  );

  late PreferencesService prefs;
  late WalletService wallet;
  late StatsRepository statsRepo;
  late BonusPlayedRepository playedRepo;

  BonusCubit newCubit(BonusAnswers pool, {int seed = 1}) => BonusCubit(
    dictionary: dict,
    pool: pool,
    config: config,
    wallet: wallet,
    statsRepo: statsRepo,
    playedRepo: playedRepo,
    random: Random(seed),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await PreferencesService.create();
    wallet = WalletService(prefs: prefs)..load();
    statsRepo = StatsRepository(prefs);
    playedRepo = BonusPlayedRepository(prefs);
  });

  // Solves the current bonus word by typing its letters after the locked prefix.
  Future<void> solveCurrent(BonusCubit cubit) async {
    final answer = cubit.state.answer;
    for (final l in answer.sublist(cubit.lockedPrefix.length)) {
      cubit.addLetter(l);
    }
    await cubit.submit();
  }

  test('solving a bonus word grants coins and tallies bonus-only stats', () async {
    final cubit = newCubit(() => [qalam]);
    cubit.start();
    expect(cubit.state.answer, qalam);

    await solveCurrent(cubit);

    expect(cubit.state.phase, BonusPhase.solved);
    expect(cubit.state.reward, config.bonusWordReward); // 40
    expect(wallet.coinBalance, config.bonusWordReward);
    final stats = statsRepo.load();
    expect(stats.bonusSolved, 1);
    expect(stats.bonusPlayed, 1);
    expect(stats.played, 0); // daily stats untouched
    expect(stats.wins, 0);
    await cubit.close();
  });

  test('bonus games never touch the streak', () async {
    // Seed a real 3-day streak, then play a bonus round.
    final streakRepo = StreakRepository(prefs);
    var streak = StreakCalculator.recordSolved(streakRepo.load(), DateTime.utc(2026, 7, 8));
    streak = StreakCalculator.recordSolved(streak, DateTime.utc(2026, 7, 9));
    streak = StreakCalculator.recordSolved(streak, DateTime.utc(2026, 7, 10));
    await streakRepo.save(streak);
    final before = streakRepo.load();

    final cubit = newCubit(() => [qalam]);
    cubit.start();
    await solveCurrent(cubit); // win

    expect(streakRepo.load(), before); // identical — streak is not advanced or reset
    await cubit.close();
  });

  test('a played bonus word never reappears', () async {
    final cubit = newCubit(() => [qalam, kitob]);
    cubit.start();
    final first = cubit.state.answer;
    await solveCurrent(cubit);
    expect(playedRepo.contains(WordTokenizer.keyOf(first)), isTrue);

    cubit.start(); // next word must be the other one
    expect(cubit.state.answer, isNot(first));
    expect(cubit.state.phase, BonusPhase.playing);
    await cubit.close();
  });

  test('an exhausted pool yields the empty phase', () async {
    final cubit = newCubit(() => [qalam]);
    cubit.start();
    await solveCurrent(cubit); // qalam now played
    cubit.start(); // nothing left
    expect(cubit.state.phase, BonusPhase.empty);
    expect(cubit.state.answer, isEmpty);
    await cubit.close();
  });
}
