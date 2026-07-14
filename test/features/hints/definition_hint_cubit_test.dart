import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_game/core/config/game_config.dart';
import 'package:word_game/core/game/data/in_memory_dictionary.dart';
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

/// Cubit-level contract for the Lugʻat (definition) hint (WS1). Daily's copy
/// is temporarily disabled — server-side guess evaluation means the client no
/// longer holds the plaintext answer needed to look up a definition — so
/// PracticeCubit is now the one place the atomic pay→show→refund logic lives.
void main() {
  const config = GameConfig();
  final clock = GameClock(config: config, now: () => DateTime.utc(2026, 7, 10, 12));
  final answer = WordTokenizer.tokenize('qalam');

  late PreferencesService prefs;
  late WalletService wallet;

  PracticeCubit cubitWith(InMemoryDictionary dict) => PracticeCubit(
    tier: PracticeTier.easy,
    dictionary: dict,
    answersForTier: (_) => [answer],
    config: config,
    wallet: wallet,
    rewardGateway: _SpyGateway(),
    clock: clock,
    repository: PracticeRepository(prefs),
  );

  // Single-entry dictionaries so the practice answer is deterministic.
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
    final cubit = cubitWith(withDef)..start(PracticeTier.easy);
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
    final cubit = cubitWith(withoutDef)..start(PracticeTier.easy);
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
    final cubit = cubitWith(withDef)..start(PracticeTier.easy);

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
    final cubit = cubitWith(withDef)..start(PracticeTier.easy);

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
