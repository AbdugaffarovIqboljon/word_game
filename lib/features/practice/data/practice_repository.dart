import 'dart:convert';

import '../../../core/storage/preferences_service.dart';
import '../domain/practice_session.dart';

/// Persists the practice session, scoped to the current puzzle date (a new day
/// starts a fresh session).
class PracticeRepository {
  PracticeRepository(this._prefs);

  static const _key = 'practice_session';

  final PreferencesService _prefs;

  String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  PracticeSession loadFor(DateTime today) {
    final key = _dateKey(today);
    final raw = _prefs.getString(_key);
    if (raw == null) return PracticeSession(dateKey: key);
    final session = PracticeSession.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    return session.dateKey == key ? session : PracticeSession(dateKey: key);
  }

  Future<void> save(PracticeSession session) =>
      _prefs.setString(_key, jsonEncode(session.toJson()));
}
