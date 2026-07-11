import '../../../core/storage/preferences_service.dart';

/// Tracks the once-per-day chest claim. The chest is "ready" (unclaimed dot
/// shown) until claimed for the current puzzle date.
class DailyChestRepository {
  DailyChestRepository(this._prefs);

  static const _claimedKey = 'daily_chest_claimed_date';

  final PreferencesService _prefs;

  bool isClaimed(DateTime today) =>
      _prefs.getString(_claimedKey) == _key(today);

  bool isReady(DateTime today) => !isClaimed(today);

  Future<void> markClaimed(DateTime today) =>
      _prefs.setString(_claimedKey, _key(today));

  String _key(DateTime d) => '${d.year}-${d.month}-${d.day}';
}
