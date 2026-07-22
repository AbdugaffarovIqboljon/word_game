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
  // WS4: difficulty reduction — 5 attempts, with the answer's first letter
  // revealed and locked on row 1. Both RC-overridable.
  int get maxAttempts => _int('max_attempts', 5);
  bool get revealFirstLetter {
    final v = _overrides['reveal_first_letter'];
    if (v is bool) return v;
    if (v is num) return v != 0; // RemoteConfig may deliver it as 0/1
    return true;
  }

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

  // ── Mystery theme hint (🔮 Mavzu) ────────────────────────────────────────
  // Kill-switch for the whole theme-hint surface (card, chip, re-expand).
  bool get hintThemeEnabled {
    final v = _overrides['hint_theme_enabled'];
    if (v is bool) return v;
    if (v is num) return v != 0; // RemoteConfig may deliver it as 0/1
    return true;
  }

  /// How long the free auto-shown card stays expanded before collapsing.
  int get hintThemeInitialSeconds => _int('hint_initial_seconds', 5);

  /// How long a paid re-expand stays visible.
  int get hintThemeReexpandSeconds => _int('hint_reexpand_seconds', 5);

  /// Coin cost of re-expanding the collapsed theme chip.
  int get hintThemeReexpandCost => _int('hint_reexpand_cost', 25);

  // ── Rewarded ad ───────────────────────────────────────────────────────────
  int get rewardedAdCoins => _int('rewarded_ad_coins', 150);

  // ── Interstitial frequency caps (enforced by the ad gateway) ─────────────
  int get interstitialMinGapSeconds => _int('interstitial_min_gap_seconds', 90);
  int get interstitialSessionWarmupSeconds =>
      _int('interstitial_session_warmup_seconds', 120);
  int get interstitialDailyCap => _int('interstitial_daily_cap', 6);
  int get resultInterstitialDailyCap =>
      _int('result_interstitial_daily_cap', 1);

  // ── Daily chest ───────────────────────────────────────────────────────────
  int get dailyChestReward => _int('daily_chest_reward', 80);
  int get dailyChestDoubleMultiplier => _int('daily_chest_double_multiplier', 2);

  // ── Reward dialogs (WS6) ─────────────────────────────────────────────────
  /// How long a reward-granted / chest-opened dialog stays up before it
  /// auto-dismisses (a tap anywhere closes it early). The chest ×2 offer dialog
  /// uses its own longer untouched-timeout, handled at the call site.
  int get rewardDialogAutoCloseMs => _int('reward_dialog_auto_close_ms', 1600);

  // ── Bonus words (WS3: pro "Yana yechish" after the daily is finished) ───────
  int get bonusWordReward => _int('bonus_word_reward', 40);

  // ── Practice ──────────────────────────────────────────────────────────────
  int practiceReward(PracticeTier tier) => switch (tier) {
    PracticeTier.easy => _int('practice_reward_easy', 10),
    PracticeTier.medium => _int('practice_reward_medium', 20),
    PracticeTier.hard => _int('practice_reward_hard', 35),
  };
  int get practiceInterstitialEvery => _int('practice_interstitial_every', 3);

  /// Free practice rounds a non-pro user may start per Tashkent day (WS1). Once
  /// exhausted, each further round is gated behind a rewarded ad
  /// ([RewardedPlacement.practiceExtra]); pro (remove_ads) owners are unlimited.
  int get practiceFreeRoundsPerDay => _int('practice_free_rounds_per_day', 3);

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

  /// Gem SKU ladder. The [GemSku.sku] ids are the store product ids the owner
  /// creates (Phase D). USD values are debug fallbacks only — at runtime the real
  /// localized price comes from the store via `in_app_purchase`. Catalog data,
  /// not a tunable scalar.
  List<GemSku> get gemSkus => const [
    GemSku(sku: 'gems_small_100', gems: 100, usd: 0.99),
    GemSku(sku: 'gems_med_350', gems: 350, usd: 2.99),
    GemSku(sku: 'gems_large_1100', gems: 1100, usd: 6.99, bestValue: true),
  ];

  /// Tile-skin catalog. `standart` is free/active; the rest are gem-priced.
  List<SkinSku> get skins => const [
    SkinSku(id: 'standart', gemPrice: 0),
    SkinSku(id: 'milliy', gemPrice: 240),
    SkinSku(id: 'neon', gemPrice: 180),
    SkinSku(id: 'oltin', gemPrice: 320),
  ];

  /// Every remotely-tunable scalar keyed by its override string. This is the
  /// single registry the RemoteConfig layer seeds its defaults from and reads
  /// overrides back into — reading each getter on a default [GameConfig] yields
  /// exactly the fallbacks, so defaults never drift from the getters above.
  /// Catalog data (gemSkus, skins) is intentionally excluded — it is replaced
  /// wholesale by code, not tuned scalar-by-scalar.
  Map<String, num> get tunables => {
    'word_length': wordLength,
    'max_attempts': maxAttempts,
    'reveal_first_letter': revealFirstLetter ? 1 : 0,
    'rollover_utc_offset_hours': rolloverUtcOffsetHours,
    'daily_base_reward': dailyBaseReward,
    'daily_speed_bonus_per_attempt': dailySpeedBonusPerAttempt,
    'daily_streak_bonus_per_day': dailyStreakBonusPerDay,
    'daily_streak_bonus_cap': dailyStreakBonusCap,
    'hint_reveal_price': hintRevealPrice,
    'hint_clean_price': hintCleanPrice,
    'hint_dictionary_price': hintDictionaryPrice,
    'hint_clean_count': hintCleanCount,
    'hint_theme_enabled': hintThemeEnabled ? 1 : 0,
    'hint_initial_seconds': hintThemeInitialSeconds,
    'hint_reexpand_seconds': hintThemeReexpandSeconds,
    'hint_reexpand_cost': hintThemeReexpandCost,
    'rewarded_ad_coins': rewardedAdCoins,
    'daily_chest_reward': dailyChestReward,
    'daily_chest_double_multiplier': dailyChestDoubleMultiplier,
    'reward_dialog_auto_close_ms': rewardDialogAutoCloseMs,
    'bonus_word_reward': bonusWordReward,
    'practice_reward_easy': practiceReward(PracticeTier.easy),
    'practice_reward_medium': practiceReward(PracticeTier.medium),
    'practice_reward_hard': practiceReward(PracticeTier.hard),
    'practice_interstitial_every': practiceInterstitialEvery,
    'practice_free_rounds_per_day': practiceFreeRoundsPerDay,
    'freeze_slots': freezeSlots,
    'freeze_buy_price_coins': freezeBuyPriceCoins,
    'streak_repair_gem_price': streakRepairGemPrice,
    'streak_repair_window_hours': streakRepairWindowHours,
    'remove_ads_bundle_usd': removeAdsBundleUsd,
    'hint_pack_usd': hintPackUsd,
    'hint_pack_count': hintPackCount,
    'starter_pack_usd': starterPackUsd,
    'starter_pack_was_usd': starterPackWasUsd,
    'starter_pack_gems': starterPackGems,
    'starter_pack_hints': starterPackHints,
    'starter_pack_window_hours': starterPackWindowHours,
    'interstitial_min_gap_seconds': interstitialMinGapSeconds,
    'interstitial_session_warmup_seconds': interstitialSessionWarmupSeconds,
    'interstitial_daily_cap': interstitialDailyCap,
    'result_interstitial_daily_cap': resultInterstitialDailyCap,
  };
}

/// Difficulty tiers for Practice mode.
enum PracticeTier { easy, medium, hard }

class GemSku extends Equatable {
  const GemSku({
    required this.sku,
    required this.gems,
    required this.usd,
    this.bonus = 0,
    this.bestValue = false,
  });

  /// Store product id created by the owner (e.g. `gems_small_100`).
  final String sku;
  final int gems;
  final double usd;
  final int bonus;
  final bool bestValue;

  int get total => gems + bonus;

  @override
  List<Object?> get props => [sku, gems, usd, bonus, bestValue];
}

class SkinSku extends Equatable {
  const SkinSku({required this.id, required this.gemPrice});

  final String id;
  final int gemPrice;

  bool get isFree => gemPrice == 0;

  @override
  List<Object?> get props => [id, gemPrice];
}
