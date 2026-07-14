import 'dart:convert';

import '../../../core/storage/preferences_service.dart';
import '../domain/daily_board_snapshot.dart';

/// Persists the current daily board snapshot.
class DailyBoardRepository {
  DailyBoardRepository(this._prefs);

  static const _key = 'daily_board';

  final PreferencesService _prefs;

  /// Returns the saved snapshot only if it belongs to [today]'s puzzle;
  /// otherwise null (a new day → fresh board, or a corrupt/incompatible
  /// snapshot — e.g. from a pre-migration build — which must never crash
  /// launch).
  DailyBoardSnapshot? loadFor(DateTime today) {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    final DailyBoardSnapshot snapshot;
    try {
      snapshot = DailyBoardSnapshot.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
    final sameDay =
        snapshot.puzzleDate.year == today.year &&
        snapshot.puzzleDate.month == today.month &&
        snapshot.puzzleDate.day == today.day;
    return sameDay ? snapshot : null;
  }

  Future<void> save(DailyBoardSnapshot snapshot) =>
      _prefs.setString(_key, jsonEncode(snapshot.toJson()));
}
