import 'package:flutter_test/flutter_test.dart';
import 'package:word_game/core/config/game_config.dart';

void main() {
  group('GameConfig defaults', () {
    const config = GameConfig();

    test('board defaults are 5 letters / 6 attempts', () {
      expect(config.wordLength, 5);
      expect(config.maxAttempts, 6);
    });

    test('practice rewards are tier-scaled 10/20/35', () {
      expect(config.practiceReward(PracticeTier.easy), 10);
      expect(config.practiceReward(PracticeTier.medium), 20);
      expect(config.practiceReward(PracticeTier.hard), 35);
    });

    test('hint prices are 150 / 100 / 75', () {
      expect(config.hintRevealPrice, 150);
      expect(config.hintCleanPrice, 100);
      expect(config.hintDictionaryPrice, 75);
    });

    test('gem ladder has three store SKUs with a best-value flag', () {
      expect(config.gemSkus, hasLength(3));
      expect(config.gemSkus.where((s) => s.bestValue), hasLength(1));
      expect(config.gemSkus.map((s) => s.sku), [
        'gems_small_100',
        'gems_med_350',
        'gems_large_1100',
      ]);
      expect(config.gemSkus[1].total, 350); // med tier, no bonus
    });
  });

  group('GameConfig overrides (RemoteConfig-ready)', () {
    test('override map wins over defaults', () {
      const config = GameConfig(overrides: {'hint_reveal_price': 999});
      expect(config.hintRevealPrice, 999);
      expect(config.hintCleanPrice, 100); // untouched default
    });
  });
}
