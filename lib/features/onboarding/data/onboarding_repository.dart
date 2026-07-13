import '../../../core/storage/preferences_service.dart';

/// Persists onboarding progress. [hasSeenOnboarding] drives the router's initial
/// redirect (decisions §8). [hasSeenRules] records whether the user actually
/// reached the color-legend step — if they skipped before it, the daily board
/// auto-opens the "Qoidalar" sheet once ([hasAutoShownRules] guards that).
class OnboardingRepository {
  OnboardingRepository(this._prefs);

  static const _seenKey = 'onboarding_seen';
  static const _rulesSeenKey = 'onboarding_rules_seen';
  static const _rulesAutoShownKey = 'daily_rules_autoshown';
  static const _tutorialCompletedKey = 'tutorial_completed';
  static const _firstDailyHintKey = 'first_daily_hint_seen';
  static const _dailyCoachKey = 'daily_coach_seen';

  final PreferencesService _prefs;

  bool get hasSeenOnboarding => _prefs.getBool(_seenKey);

  Future<void> markSeen() => _prefs.setBool(_seenKey, true);

  /// True once the user has viewed the color-legend (onboarding step 2).
  bool get hasSeenRules => _prefs.getBool(_rulesSeenKey);

  Future<void> markRulesSeen() => _prefs.setBool(_rulesSeenKey, true);

  /// True once the daily board has auto-opened the rules sheet for a skipper.
  bool get hasAutoShownRules => _prefs.getBool(_rulesAutoShownKey);

  Future<void> markRulesAutoShown() => _prefs.setBool(_rulesAutoShownKey, true);

  /// True once the user has finished the guided tutorial (win or gentle reveal).
  /// Persisted separately from [hasSeenOnboarding] so a skip does not count as
  /// completion (WS1).
  bool get hasCompletedTutorial => _prefs.getBool(_tutorialCompletedKey);

  Future<void> markTutorialCompleted() =>
      _prefs.setBool(_tutorialCompletedKey, true);

  /// Whether the special first-ever daily board ghost affordance is still due
  /// ("Istalgan soʻzdan boshlang — ranglar yoʻl koʻrsatadi").
  bool get hasSeenFirstDailyHint => _prefs.getBool(_firstDailyHintKey);

  Future<void> markFirstDailyHintSeen() =>
      _prefs.setBool(_firstDailyHintKey, true);

  /// Whether the "N urinish / first letter given" coach mark on the daily board
  /// has been dismissed. A classic one-time coach mark — dismissed on tap.
  bool get hasSeenDailyCoach => _prefs.getBool(_dailyCoachKey);

  Future<void> markDailyCoachSeen() => _prefs.setBool(_dailyCoachKey, true);
}
