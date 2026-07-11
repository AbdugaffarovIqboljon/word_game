import '../../../core/storage/preferences_service.dart';

/// Per-day outcome for the streak heat-map.
enum DayStatus { played, frozen, missed, empty, future }

/// Records which puzzle dates were solved or saved-by-freeze, so the streak
/// screen can render a real 30-day heat-map. Kept separate from [StreakData]
/// (which is just counters) — this is the day-by-day history.
class StreakHistoryRepository {
  StreakHistoryRepository(this._prefs);

  static const _solvedKey = 'streak_solved_dates';
  static const _frozenKey = 'streak_frozen_dates';
  static const _cap = 120; // keep ~4 months

  final PreferencesService _prefs;

  static String keyOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Set<String> get _solved => _prefs.getStringList(_solvedKey).toSet();
  Set<String> get _frozen => _prefs.getStringList(_frozenKey).toSet();

  Future<void> markSolved(DateTime date) =>
      _add(_solvedKey, [keyOf(date)]);

  Future<void> markFrozen(Iterable<DateTime> dates) =>
      _add(_frozenKey, dates.map(keyOf));

  Future<void> _add(String key, Iterable<String> newKeys) {
    final list = _prefs.getStringList(key).toSet()..addAll(newKeys);
    final sorted = list.toList()..sort();
    final trimmed = sorted.length > _cap
        ? sorted.sublist(sorted.length - _cap)
        : sorted;
    return _prefs.setStringList(key, trimmed);
  }

  /// Status of each of the last [days] days, oldest first, relative to [today].
  List<DayStatus> lastDays(DateTime today, {int days = 30}) {
    final solved = _solved;
    final frozen = _frozen;
    final earliest = solved.isEmpty
        ? null
        : (solved.toList()..sort()).first;

    return List.generate(days, (i) {
      final date = today.subtract(Duration(days: days - 1 - i));
      final key = keyOf(date);
      if (date.isAfter(today)) return DayStatus.future;
      if (solved.contains(key)) return DayStatus.played;
      if (frozen.contains(key)) return DayStatus.frozen;
      if (earliest != null && key.compareTo(earliest) >= 0) {
        return DayStatus.missed;
      }
      return DayStatus.empty;
    });
  }
}
