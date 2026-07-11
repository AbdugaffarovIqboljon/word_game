import 'package:flutter/foundation.dart';

import '../../../core/storage/preferences_service.dart';

/// Tracks non-consumable entitlements (remove-ads) and owned product ids. The
/// [removeAds] flag is reactive and read by the practice interstitial gate.
class PurchasesRepository {
  PurchasesRepository(this._prefs);

  static const _removeAdsKey = 'iap_remove_ads';
  static const _ownedKey = 'iap_owned';

  final PreferencesService _prefs;

  final ValueNotifier<bool> removeAds = ValueNotifier(false);

  void load() => removeAds.value = _prefs.getBool(_removeAdsKey);

  Future<void> setRemoveAds(bool value) {
    removeAds.value = value;
    return _prefs.setBool(_removeAdsKey, value);
  }

  /// Deadline for the time-limited starter pack; the start is stamped on first
  /// read so the countdown is stable across launches.
  DateTime starterDeadline(Duration window) {
    const key = 'starter_start_ms';
    var startMs = _prefs.getInt(key);
    if (startMs == 0) {
      startMs = DateTime.now().millisecondsSinceEpoch;
      _prefs.setInt(key, startMs);
    }
    return DateTime.fromMillisecondsSinceEpoch(startMs).add(window);
  }

  bool isOwned(String productId) =>
      _prefs.getStringList(_ownedKey).contains(productId);

  Future<void> markOwned(String productId) {
    final next = (_prefs.getStringList(_ownedKey).toSet()..add(productId)).toList();
    return _prefs.setStringList(_ownedKey, next);
  }

  void dispose() => removeAds.dispose();
}
