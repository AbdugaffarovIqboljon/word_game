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

class _SpyGateway implements RewardGateway {
  int interstitials = 0;
  final ValueNotifier<bool> _ready = ValueNotifier<bool>(true);
  @override
  Future<bool> showRewardedAd(RewardedPlacement placement) async => true;
  @override
  Future<void> showInterstitial(InterstitialPlacement placement) async =>
      interstitials++;
  @override
  ValueListenable<bool> isReady(RewardedPlacement placement) => _ready;
}

void main() {
  const config = GameConfig();
  final dict = InMemoryDictionary(
    entries: const [
      DictionaryEntry('qalam', 'Yozuv quroli'),
      DictionaryEntry('kitob', 'Oʻqish uchun asar'),
    ],
  );
  final answer = WordTokenizer.tokenize('qalam');
  final wrong = WordTokenizer.tokenize('kitob');
  List<List<LogicalLetter>> answersForTier(PracticeTier _) => [answer];

  final clock = GameClock(config: config, now: () => DateTime.utc(2026, 7, 10, 12));

  late PreferencesService prefs;
  late WalletService wallet;
  late _SpyGateway gateway;

  PracticeCubit newCubit() => PracticeCubit(
    tier: PracticeTier.easy,
    dictionary: dict,
    answersForTier: answersForTier,
    config: config,
    wallet: wallet,
    rewardGateway: gateway,
    clock: clock,
    repository: PracticeRepository(prefs),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await PreferencesService.create();
    wallet = WalletService(prefs: prefs)..load();
    gateway = _SpyGateway();
  });

  Future<void> typeWord(PracticeCubit c, List<LogicalLetter> w) async {
    for (final l in w) {
      c.addLetter(l);
    }
    await c.submit();
  }

  test('start begins a playing round with an answer', () {
    final cubit = newCubit()..start(PracticeTier.easy);
    expect(cubit.state.phase, PracticePhase.playing);
    expect(cubit.state.answer, answer);
    cubit.close();
  });

  test('solving credits the tier reward and the session', () async {
    final cubit = newCubit()..start(PracticeTier.easy);
    await typeWord(cubit, answer);
    expect(cubit.state.phase, PracticePhase.solved);
    expect(cubit.state.reward, config.practiceReward(PracticeTier.easy)); // 10
    expect(wallet.coinBalance, 10);
    expect(PracticeRepository(prefs).loadFor(clock.puzzleDate()).solved, 1);
    await cubit.close();
  });

  test('six wrong guesses fail the round', () async {
    final cubit = newCubit()..start(PracticeTier.easy);
    for (var i = 0; i < 6; i++) {
      await typeWord(cubit, wrong);
    }
    expect(cubit.state.phase, PracticePhase.failed);
    await cubit.close();
  });

  test('again() starts a fresh round (new nonce, playing)', () async {
    final cubit = newCubit()..start(PracticeTier.easy);
    await typeWord(cubit, answer);
    final nonce = cubit.state.roundNonce;
    await cubit.again();
    expect(cubit.state.phase, PracticePhase.playing);
    expect(cubit.state.roundNonce, greaterThan(nonce));
    await cubit.close();
  });

  test('interstitial shows on every 3rd solve', () async {
    final cubit = newCubit()..start(PracticeTier.easy);
    for (var round = 0; round < 3; round++) {
      await typeWord(cubit, answer);
      await cubit.again();
    }
    // 3 solves → the again() after the 3rd solve triggers one interstitial.
    expect(gateway.interstitials, 1);
    await cubit.close();
  });
}
