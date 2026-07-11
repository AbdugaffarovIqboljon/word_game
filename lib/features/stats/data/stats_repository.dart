import 'dart:convert';

import '../../../core/storage/preferences_service.dart';
import '../domain/stats_data.dart';

/// Persists [StatsData] as JSON in shared preferences.
class StatsRepository {
  StatsRepository(this._prefs);

  static const _key = 'stats_data';

  final PreferencesService _prefs;

  StatsData load() {
    final raw = _prefs.getString(_key);
    if (raw == null) return StatsData();
    return StatsData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(StatsData data) =>
      _prefs.setString(_key, jsonEncode(data.toJson()));
}
