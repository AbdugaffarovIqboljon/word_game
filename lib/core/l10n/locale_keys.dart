/// Hand-maintained localization key constants (mirrors
/// `assets/translations/*.json`). Kept manual instead of easy_localization's
/// codegen so the build has no extra generation step; the JSON and this file
/// are edited together. Use with `.tr()`, e.g. `LocaleKeys.dailySubtitle.tr()`.
abstract final class LocaleKeys {
  const LocaleKeys._();

  static const appTitle = 'app.title';

  static const commonBack = 'common.back';
  static const commonClose = 'common.close';
  static const commonCancel = 'common.cancel';
  static const commonContinue = 'common.continue';
  static const commonStart = 'common.start';
  static const commonSkip = 'common.skip';
  static const commonDomain = 'common.domain';
  static const commonRules = 'common.rules';

  static const onboardingWelcomeTagline = 'onboarding.welcome_tagline';
  static const onboardingRulesTitle = 'onboarding.rules_title';
  static const onboardingRuleCorrect = 'onboarding.rule_correct';
  static const onboardingRulePresent = 'onboarding.rule_present';
  static const onboardingRuleAbsent = 'onboarding.rule_absent';
  static const onboardingTryTitle = 'onboarding.try_title';
  static const onboardingTryCoachmark = 'onboarding.try_coachmark';

  static const dailySubtitle = 'daily.subtitle';
  static const dailyPuzzleNumber = 'daily.puzzle_number';
  static const dailyGhostHint = 'daily.ghost_hint';
  static const dailyTooShort = 'daily.too_short';
  static const dailyPracticePill = 'daily.practice_pill';
  static const dailyInvalidWord = 'daily.invalid_word';
  static const dailySolvedHeadline = 'daily.solved_headline';
  static const dailySolvedAttempts = 'daily.solved_attempts';
  static const dailyCoinsEarned = 'daily.coins_earned';
  static const dailyNextWord = 'daily.next_word';
  static const dailyNextWordIn = 'daily.next_word_in';
  static const dailyShareResult = 'daily.share_result';
  static const dailyFailedLabel = 'daily.failed_label';

  static const shareNavTitle = 'share.nav_title';
  static const shareCardHeader = 'share.card_header';
  static const shareTelegram = 'share.telegram';
  static const shareStories = 'share.stories';
  static const shareCopy = 'share.copy';
  static const shareCopied = 'share.copied';
  static const shareBreakdownBase = 'share.breakdown_base';
  static const shareBreakdownSpeed = 'share.breakdown_speed';
  static const shareBreakdownStreak = 'share.breakdown_streak';
  static const shareBreakdownTotal = 'share.breakdown_total';
  static const sharePracticeCta = 'share.practice_cta';
  static const shareTelegramCaption = 'share.telegram_caption';
  static const shareCrossPromo = 'share.cross_promo';

  static const practiceNavTitle = 'practice.nav_title';
  static const practiceTierEasy = 'practice.tier_easy';
  static const practiceTierMedium = 'practice.tier_medium';
  static const practiceTierHard = 'practice.tier_hard';
  static const practiceTierReward = 'practice.tier_reward';
  static const practiceSessionTitle = 'practice.session_title';
  static const practiceSessionSolved = 'practice.session_solved';
  static const practiceSessionAccuracy = 'practice.session_accuracy';
  static const practiceSessionCoins = 'practice.session_coins';
  static const practiceAdNotice = 'practice.ad_notice';
  static const practiceRoundLabel = 'practice.round_label';
  static const practiceAgain = 'practice.again';
  static const practiceNextTier = 'practice.next_tier';
  static const practiceSolvedOverlay = 'practice.solved_overlay';
  static const practiceFailedOverlay = 'practice.failed_overlay';

  static const hintTitle = 'hint.title';
  static const hintRevealName = 'hint.reveal_name';
  static const hintRevealDesc = 'hint.reveal_desc';
  static const hintCleanName = 'hint.clean_name';
  static const hintCleanDesc = 'hint.clean_desc';
  static const hintDictionaryName = 'hint.dictionary_name';
  static const hintDictionaryDesc = 'hint.dictionary_desc';
  static const hintWatchAd = 'hint.watch_ad';
  static const hintInsufficient = 'hint.insufficient';
  static const hintLocked = 'hint.locked';

  static const statsNavTitle = 'stats.nav_title';
  static const statsPlayed = 'stats.played';
  static const statsWinRate = 'stats.win_rate';
  static const statsStreak = 'stats.streak';
  static const statsBest = 'stats.best';
  static const statsDistribution = 'stats.distribution';
  static const statsSuccessNote = 'stats.success_note';

  static const shopNavTitle = 'shop.nav_title';
  static const shopBestOffer = 'shop.best_offer';
  static const shopHeroTitle = 'shop.hero_title';
  static const shopHeroSubtitle = 'shop.hero_subtitle';
  static const shopBestValue = 'shop.best_value';
  static const shopBonusGems = 'shop.bonus_gems';
  static const shopHintPackTitle = 'shop.hint_pack_title';
  static const shopHintPackSubtitle = 'shop.hint_pack_subtitle';
  static const shopStarterTitle = 'shop.starter_title';
  static const shopStarterSubtitle = 'shop.starter_subtitle';
  static const shopStarterEndsIn = 'shop.starter_ends_in';
  static const shopSkinsTitle = 'shop.skins_title';
  static const shopSkinStandart = 'shop.skin_standart';
  static const shopSkinMilliy = 'shop.skin_milliy';
  static const shopSkinNeon = 'shop.skin_neon';
  static const shopSkinOltin = 'shop.skin_oltin';
  static const shopSkinActive = 'shop.skin_active';
  static const shopSkinApply = 'shop.skin_apply';
  static const shopRestore = 'shop.restore';

  static const streakNavTitle = 'streak.nav_title';
  static const streakPersonalBest = 'streak.personal_best';
  static const streakSubtitle = 'streak.subtitle';
  static const streakFreezeTitle = 'streak.freeze_title';
  static const streakFreezeGet = 'streak.freeze_get';
  static const streakFreezeEmpty = 'streak.freeze_empty';
  static const streakFreezeReady = 'streak.freeze_ready';
  static const streakBrokenTitle = 'streak.broken_title';
  static const streakBrokenBody = 'streak.broken_body';
  static const streakRepair = 'streak.repair';
  static const streakRepairDecline = 'streak.repair_decline';
  static const streakRepairEndsIn = 'streak.repair_ends_in';
  static const streakConsumedTitle = 'streak.consumed_title';
  static const streakConsumedBody = 'streak.consumed_body';

  static const settingsNavTitle = 'settings.nav_title';
  static const settingsLanguage = 'settings.language';
  static const settingsLangUzLatn = 'settings.lang_uz_latn';
  static const settingsLangRu = 'settings.lang_ru';
  static const settingsLangUzCyrl = 'settings.lang_uz_cyrl';
  static const settingsComingSoon = 'settings.coming_soon';
  static const settingsSound = 'settings.sound';
  static const settingsHaptics = 'settings.haptics';
  static const settingsNotifications = 'settings.notifications';
  static const settingsRemoveAds = 'settings.remove_ads';
  static const settingsRestore = 'settings.restore';
  static const settingsVersion = 'settings.version';

  static const dialogRewardedTitle = 'dialog.rewarded_title';
  static const dialogRewardedBody = 'dialog.rewarded_body';
  static const dialogRewardedCta = 'dialog.rewarded_cta';
  static const dialogGrantedTitle = 'dialog.granted_title';
  static const dialogGrantedBody = 'dialog.granted_body';
  static const dialogGrantedAmount = 'dialog.granted_amount';
  static const dialogGrantedCta = 'dialog.granted_cta';
  static const dialogChestTitle = 'dialog.chest_title';
  static const dialogChestReady = 'dialog.chest_ready';
  static const dialogChestOpen = 'dialog.chest_open';
  static const dialogChestReward = 'dialog.chest_reward';
  static const dialogChestOpened = 'dialog.chest_opened';
  static const dialogChestClaimed = 'dialog.chest_claimed';
  static const dialogChestDoubleTitle = 'dialog.chest_double_title';
  static const dialogChestDoubleSubtitle = 'dialog.chest_double_subtitle';
  static const dialogChestDoubleCta = 'dialog.chest_double_cta';
}
