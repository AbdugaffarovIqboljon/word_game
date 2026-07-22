import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_game/core/config/game_config.dart';
import 'package:word_game/core/game/data/in_memory_dictionary.dart';
import 'package:word_game/core/game/domain/logical_letter.dart';
import 'package:word_game/core/game/domain/word_tokenizer.dart';
import 'package:word_game/core/storage/preferences_service.dart';
import 'package:word_game/core/time/game_clock.dart';
import 'package:word_game/features/ads/domain/reward_gateway.dart';
import 'package:word_game/features/practice/data/practice_repository.dart';
import 'package:word_game/features/practice/presentation/practice_cubit.dart';
import 'package:word_game/features/practice/presentation/practice_state.dart';
import 'package:word_game/features/wallet/data/wallet_service.dart';

/// WS1 — free practice-round ladder: N free rounds per Tashkent day, then a
/// rewarded ad per extra round; pro is unlimited.
class _SpyGateway implements RewardGateway {
  int interstitials = 0;
  final ValueNotifier<bool> ready = ValueNotifier<bool>(true);
  @override
  Future<bool> showRewardedAd(RewardedPlacement placement) async => true;
  @override
  Future<void> showInterstitial(InterstitialPlacement placement) async =>
      interstitials++;
  @override
  ValueListenable<bool> isReady(RewardedPlacement placement) => ready;
}

void main() {
  const config = GameConfig(overrides: {
    'reveal_first_letter': false,
    'practice_free_rounds_per_day': 3,
  });
  final dict = InMemoryDictionary(
    entries: const [DictionaryEntry('qalam', 'Yozuv quroli')],
  );
  final answer = WordTokenizer.tokenize('qalam');
  List<List<LogicalLetter>> answersForTier(PracticeTier _) => [answer];

  late PreferencesService prefs;
  late WalletService wallet;
  late _SpyGateway gateway;
  late DateTime nowUtc;
  late GameClock clock;
  late PracticeRepository repo;

  PracticeCubit newCubit({bool pro = false}) => PracticeCubit(
        tier: PracticeTier.easy,
        dictionary: dict,
        answersForTier: answersForTier,
        config: config,
        wallet: wallet,
        rewardGateway: gateway,
        clock: clock,
        repository: repo,
        removeAds: pro,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await PreferencesService.create();
    wallet = WalletService(prefs: prefs)..load();
    gateway = _SpyGateway();
    nowUtc = DateTime.utc(2026, 7, 10, 12);
    clock = GameClock(config: config, now: () => nowUtc);
    repo = PracticeRepository(prefs);
  });

  test('free rounds decrement per start; gate flips after the allotment', () {
    final cubit = newCubit();
    cubit.start(PracticeTier.easy);
    expect(cubit.freeRoundsRemaining, 2);
    expect(cubit.nextRoundIsFree, isTrue);

    cubit.start(PracticeTier.easy);
    expect(cubit.freeRoundsRemaining, 1);

    cubit.start(PracticeTier.easy);
    expect(cubit.freeRoundsRemaining, 0);
    expect(cubit.nextRoundIsFree, isFalse); // exhausted → ad required
    cubit.close();
  });

  test('the counter resets at the Tashkent-day rollover', () {
    final cubit = newCubit();
    cubit.start(PracticeTier.easy);
    cubit.start(PracticeTier.easy);
    cubit.start(PracticeTier.easy);
    expect(cubit.freeRoundsRemaining, 0);

    // Next day: start() reloads the session for the new date, resetting starts.
    nowUtc = DateTime.utc(2026, 7, 11, 12);
    cubit.start(PracticeTier.easy);
    expect(cubit.freeRoundsRemaining, 2);
    expect(cubit.nextRoundIsFree, isTrue);
    cubit.close();
  });

  test('an ad-granted extra round starts play without an interstitial', () async {
    final cubit = newCubit();
    cubit.start(PracticeTier.easy);
    cubit.start(PracticeTier.easy);
    cubit.start(PracticeTier.easy);
    expect(cubit.nextRoundIsFree, isFalse);

    // The play page, after a completed rewarded ad, calls again(skipInterstitial:
    // true) — exactly one extra round, no stacked interstitial.
    await cubit.again(skipInterstitial: true);
    expect(cubit.state.phase, PracticePhase.playing);
    expect(cubit.freeRoundsRemaining, 0); // still exhausted; each extra needs an ad
    expect(gateway.interstitials, 0);
    cubit.close();
  });

  test('pro (remove_ads) is unlimited and never gated', () {
    final cubit = newCubit(pro: true);
    for (var i = 0; i < 5; i++) {
      cubit.start(PracticeTier.easy);
      expect(cubit.nextRoundIsFree, isTrue);
    }
    expect(cubit.freeRoundsRemaining, 3); // reported as the full allotment
    expect(cubit.isPro, isTrue);
    cubit.close();
  });
}
