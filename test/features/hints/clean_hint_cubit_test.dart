import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_game/core/config/game_config.dart';
import 'package:word_game/core/game/data/in_memory_dictionary.dart';
import 'package:word_game/core/game/domain/letter_result.dart';
import 'package:word_game/core/game/domain/logical_letter.dart';
import 'package:word_game/core/game/domain/word_tokenizer.dart';
import 'package:word_game/core/storage/preferences_service.dart';
import 'package:word_game/core/time/game_clock.dart';
import 'package:word_game/features/ads/domain/reward_gateway.dart';
import 'package:word_game/features/practice/data/practice_repository.dart';
import 'package:word_game/features/practice/presentation/practice_cubit.dart';
import 'package:word_game/features/wallet/data/wallet_service.dart';

class _SpyGateway implements RewardGateway {
  final ValueNotifier<bool> _ready = ValueNotifier<bool>(true);
  @override
  Future<bool> showRewardedAd(RewardedPlacement placement) async => true;
  @override
  Future<void> showInterstitial(InterstitialPlacement placement) async {}
  @override
  ValueListenable<bool> isReady(RewardedPlacement placement) => _ready;
}

/// Cubit-level contract for the clean-keyboard hint (WS3). Daily's copy of
/// this hint is temporarily disabled — server-side guess evaluation means the
/// client no longer holds the plaintext answer needed to pick absent letters
/// — so PracticeCubit is now the one place this behavior lives.
void main() {
  const config = GameConfig();
  final dict = InMemoryDictionary(
    entries: const [
      DictionaryEntry('qalam', 'Yozuv quroli'),
      DictionaryEntry('kitob', 'Oʻqish uchun asar'),
    ],
  );
  final answer = WordTokenizer.tokenize('qalam');
  List<List<LogicalLetter>> answersForTier(PracticeTier _) => [answer];
  final clock = GameClock(config: config, now: () => DateTime.utc(2026, 7, 10, 12));

  late PreferencesService prefs;
  late WalletService wallet;

  PracticeCubit newCubit() => PracticeCubit(
    tier: PracticeTier.easy,
    dictionary: dict,
    answersForTier: answersForTier,
    config: config,
    wallet: wallet,
    rewardGateway: _SpyGateway(),
    clock: clock,
    repository: PracticeRepository(prefs),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await PreferencesService.create();
    wallet = WalletService(prefs: prefs)..load();
  });

  test('normal case grays exactly hintCleanCount absent letters', () async {
    final cubit = newCubit()..start(PracticeTier.easy);
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
    final cubit = newCubit()..start(PracticeTier.easy);
    final first = cubit.cleanKeyboard().toSet();
    final second = cubit.cleanKeyboard().toSet();
    expect(first.intersection(second), isEmpty);
    await cubit.close();
  });

  test('atomic success charges once and never refunds', () async {
    final cubit = newCubit()..start(PracticeTier.easy);
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
    final cubit = newCubit()..start(PracticeTier.easy);

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
    final cubit = newCubit()..start(PracticeTier.easy);
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
