import 'package:equatable/equatable.dart';

/// Single source of truth for every economy / game constant.
///
/// Values are read through **keyed getters** backed by an [overrides] map. Today
/// the map is empty (plain defaults); wiring a RemoteConfig / Firebase source is
/// a drop-in later — fetch the JSON, pass it as [overrides], done. No call site
/// changes. Registered as a singleton in the service locator.
class GameConfig {
  const GameConfig({Map<String, Object> overrides = const {}})
    : _overrides = overrides;

  final Map<String, Object> _overrides;

  int _int(String key, int fallback) =>
      (_overrides[key] as num?)?.toInt() ?? fallback;

  double _double(String key, double fallback) =>
      (_overrides[key] as num?)?.toDouble() ?? fallback;

  // ── Board ─────────────────────────────────────────────────────────────────
  int get wordLength => _int('word_length', 5);
  int get maxAttempts => _int('max_attempts', 6);

  // ── Timezone (word rollover at Tashkent midnight, UTC+5) ─────────────────
  int get rolloverUtcOffsetHours => _int('rollover_utc_offset_hours', 5);

  // ── Daily reward breakdown ────────────────────────────────────────────────
  int get dailyBaseReward => _int('daily_base_reward', 40);
  int get dailySpeedBonusPerAttempt => _int('daily_speed_bonus_per_attempt', 10);
  int get dailyStreakBonusPerDay => _int('daily_streak_bonus_per_day', 5);
  int get dailyStreakBonusCap => _int('daily_streak_bonus_cap', 100);

  // ── Hints ─────────────────────────────────────────────────────────────────
  int get hintRevealPrice => _int('hint_reveal_price', 150);
  int get hintCleanPrice => _int('hint_clean_price', 100);
  int get hintDictionaryPrice => _int('hint_dictionary_price', 75);
  int get hintCleanCount => _int('hint_clean_count', 5);

  // ── Rewarded ad ───────────────────────────────────────────────────────────
  int get rewardedAdCoins => _int('rewarded_ad_coins', 150);

  // ── Daily chest ───────────────────────────────────────────────────────────
  int get dailyChestReward => _int('daily_chest_reward', 80);
  int get dailyChestDoubleMultiplier => _int('daily_chest_double_multiplier', 2);

  // ── Practice ──────────────────────────────────────────────────────────────
  int practiceReward(PracticeTier tier) => switch (tier) {
    PracticeTier.easy => _int('practice_reward_easy', 10),
    PracticeTier.medium => _int('practice_reward_medium', 20),
    PracticeTier.hard => _int('practice_reward_hard', 35),
  };
  int get practiceInterstitialEvery => _int('practice_interstitial_every', 3);

  // ── Streak & freeze ───────────────────────────────────────────────────────
  int get freezeSlots => _int('freeze_slots', 2);
  int get freezeBuyPriceCoins => _int('freeze_buy_price_coins', 200);
  int get streakRepairGemPrice => _int('streak_repair_gem_price', 50);
  int get streakRepairWindowHours => _int('streak_repair_window_hours', 48);

  // ── Shop: IAP ─────────────────────────────────────────────────────────────
  double get removeAdsBundleUsd => _double('remove_ads_bundle_usd', 2.99);
  double get hintPackUsd => _double('hint_pack_usd', 1.99);
  int get hintPackCount => _int('hint_pack_count', 10);

  double get starterPackUsd => _double('starter_pack_usd', 3.99);
  double get starterPackWasUsd => _double('starter_pack_was_usd', 9.99);
  int get starterPackGems => _int('starter_pack_gems', 500);
  int get starterPackHints => _int('starter_pack_hints', 20);
  int get starterPackWindowHours => _int('starter_pack_window_hours', 48);

  /// Gem SKU ladder (100/550/1200/2500). Catalog data, not a scalar — kept const
  /// here; a remote override would replace the whole list.
  List<GemSku> get gemSkus => const [
    GemSku(gems: 100, usd: 0.99),
    GemSku(gems: 550, usd: 4.99, bonus: 50),
    GemSku(gems: 1200, usd: 9.99, bonus: 150),
    GemSku(gems: 2500, usd: 19.99, bonus: 0, bestValue: true),
  ];

  /// Tile-skin catalog. `standart` is free/active; the rest are gem-priced.
  List<SkinSku> get skins => const [
    SkinSku(id: 'standart', gemPrice: 0),
    SkinSku(id: 'milliy', gemPrice: 240),
    SkinSku(id: 'neon', gemPrice: 180),
    SkinSku(id: 'oltin', gemPrice: 320),
  ];
}

/// Difficulty tiers for Practice mode.
enum PracticeTier { easy, medium, hard }

class GemSku extends Equatable {
  const GemSku({
    required this.gems,
    required this.usd,
    this.bonus = 0,
    this.bestValue = false,
  });

  final int gems;
  final double usd;
  final int bonus;
  final bool bestValue;

  int get total => gems + bonus;

  @override
  List<Object?> get props => [gems, usd, bonus, bestValue];
}

class SkinSku extends Equatable {
  const SkinSku({required this.id, required this.gemPrice});

  final String id;
  final int gemPrice;

  bool get isFree => gemPrice == 0;

  @override
  List<Object?> get props => [id, gemPrice];
}
