import '../../../core/storage/preferences_service.dart';

/// Persists whether the one-time onboarding flow has been completed. Drives the
/// router's initial redirect (decisions §8: onboarding shown once).
class OnboardingRepository {
  OnboardingRepository(this._prefs);

  static const _seenKey = 'onboarding_seen';

  final PreferencesService _prefs;

  bool get hasSeenOnboarding => _prefs.getBool(_seenKey);

  Future<void> markSeen() => _prefs.setBool(_seenKey, true);
}
