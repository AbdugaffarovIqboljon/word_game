import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/storage/preferences_service.dart';
import '../domain/practice_session.dart';

/// Persists the practice session, scoped to the current puzzle date (a new day
/// starts a fresh session).
///
/// WS5: [current] exposes today's session as a listenable so the Practice hub
/// updates the "Bugungi sessiya" row live — it changes on every [save] (each
/// game end) and on every [loadFor] (which the hub calls on entry / route return
/// so a Tashkent-midnight rollover resets the numbers).
class PracticeRepository {
  PracticeRepository(this._prefs);

  static const _key = 'practice_session';

  final PreferencesService _prefs;

  final ValueNotifier<PracticeSession> _current =
      ValueNotifier(const PracticeSession(dateKey: ''));

  /// Today's session, kept in sync with [loadFor] / [save]. Equatable, so the
  /// notifier only fires when the totals actually change.
  ValueListenable<PracticeSession> get current => _current;

  String _dateKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  PracticeSession loadFor(DateTime today) {
    final key = _dateKey(today);
    final raw = _prefs.getString(_key);
    final session = raw == null
        ? PracticeSession(dateKey: key)
        : _forKey(PracticeSession.fromJson(jsonDecode(raw) as Map<String, dynamic>), key);
    _current.value = session;
    return session;
  }

  PracticeSession _forKey(PracticeSession stored, String key) =>
      stored.dateKey == key ? stored : PracticeSession(dateKey: key);

  Future<void> save(PracticeSession session) {
    _current.value = session;
    return _prefs.setString(_key, jsonEncode(session.toJson()));
  }
}
