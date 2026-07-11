import 'dart:convert';

import '../../../core/storage/preferences_service.dart';
import '../domain/streak_calculator.dart';
import '../domain/streak_data.dart';

/// Persists [StreakData] as JSON in shared preferences, plus a one-shot
/// "reconcile outcome" flag set at launch (freeze consumed / streak broken) so
/// the Streak screen can surface the freeze-consumed dialog exactly once.
class StreakRepository {
  StreakRepository(this._prefs);

  static const _key = 'streak_data';
  static const _pendingKey = 'streak_pending_outcome';

  final PreferencesService _prefs;

  StreakData load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return const StreakData();
    return StreakData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(StreakData data) =>
      _prefs.setString(_key, jsonEncode(data.toJson()));

  Future<void> setPendingOutcome(StreakOutcome outcome) =>
      _prefs.setString(_pendingKey, outcome.name);

  /// Reads and clears the pending launch-reconcile outcome.
  Future<StreakOutcome?> takePendingOutcome() async {
    final raw = _prefs.getString(_pendingKey);
    if (raw == null) return null;
    await _prefs.remove(_pendingKey);
    return StreakOutcome.values.asNameMap()[raw];
  }
}
