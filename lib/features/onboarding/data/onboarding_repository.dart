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

  final PreferencesService _prefs;

  bool get hasSeenOnboarding => _prefs.getBool(_seenKey);

  Future<void> markSeen() => _prefs.setBool(_seenKey, true);

  /// True once the user has viewed the color-legend (onboarding step 2).
  bool get hasSeenRules => _prefs.getBool(_rulesSeenKey);

  Future<void> markRulesSeen() => _prefs.setBool(_rulesSeenKey, true);

  /// True once the daily board has auto-opened the rules sheet for a skipper.
  bool get hasAutoShownRules => _prefs.getBool(_rulesAutoShownKey);

  Future<void> markRulesAutoShown() => _prefs.setBool(_rulesAutoShownKey, true);
}
