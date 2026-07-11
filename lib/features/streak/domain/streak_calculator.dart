import 'streak_data.dart';

/// What happened to the streak when reconciling missed days on launch.
enum StreakOutcome { none, savedByFreeze, broken }

class StreakReconcileResult {
  const StreakReconcileResult(this.data, this.outcome, this.freezesConsumed);
  final StreakData data;
  final StreakOutcome outcome;
  final int freezesConsumed;
}

/// Pure streak state machine. No storage, no clock — every operation takes the
/// current [StreakData] and the puzzle date to evaluate against, so all of it is
/// unit-testable including timezone/day-boundary edges.
abstract final class StreakCalculator {
  const StreakCalculator._();

  /// Whole days from date-only [a] to date-only [b].
  static int _days(DateTime a, DateTime b) =>
      DateTime.utc(b.year, b.month, b.day)
          .difference(DateTime.utc(a.year, a.month, a.day))
          .inDays;

  static DateTime _dayBefore(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).subtract(const Duration(days: 1));

  /// Reconciles missed days between [data.anchorDate] and [today]. Consumes
  /// freezes to cover gaps if possible; otherwise breaks the streak. Idempotent
  /// within the same day (a saved day advances the anchor so it is not
  /// re-charged next launch).
  static StreakReconcileResult reconcile(StreakData data, DateTime today) {
    final anchor = data.anchorDate;
    if (anchor == null) {
      return StreakReconcileResult(data, StreakOutcome.none, 0);
    }
    final gap = _days(anchor, today);
    if (gap <= 1) {
      // gap 0 = anchor is today; gap 1 = yesterday → still consecutive.
      return StreakReconcileResult(data, StreakOutcome.none, 0);
    }
    final missed = gap - 1;
    if (data.freezes >= missed) {
      return StreakReconcileResult(
        data.copyWith(
          freezes: data.freezes - missed,
          anchorDate: _dayBefore(today),
        ),
        StreakOutcome.savedByFreeze,
        missed,
      );
    }
    // Not enough freezes → streak breaks.
    return StreakReconcileResult(
      data.copyWith(
        current: 0,
        anchorDate: null,
        brokenStreakValue: data.current > 0
            ? data.current
            : data.brokenStreakValue,
        brokenAtDate: today,
      ),
      StreakOutcome.broken,
      0,
    );
  }

  /// Records a solved daily on [today]. Assumes [reconcile] has already run.
  static StreakData recordSolved(StreakData data, DateTime today) {
    if (data.lastSolvedDate != null && _days(data.lastSolvedDate!, today) == 0) {
      return data; // already counted today
    }
    final anchor = data.anchorDate;
    final int newCurrent;
    if (anchor == null) {
      newCurrent = 1;
    } else if (_days(anchor, today) == 1) {
      newCurrent = data.current + 1;
    } else if (_days(anchor, today) == 0) {
      newCurrent = data.current == 0 ? 1 : data.current;
    } else {
      newCurrent = 1;
    }
    return data.copyWith(
      current: newCurrent,
      best: newCurrent > data.best ? newCurrent : data.best,
      anchorDate: today,
      lastSolvedDate: today,
      brokenStreakValue: null,
      brokenAtDate: null,
    );
  }

  /// Records a failed daily on [today] — an active loss breaks the streak
  /// immediately (no freeze protection; freezes only cover *unplayed* days).
  static StreakData recordFail(StreakData data, DateTime today) {
    return data.copyWith(
      current: 0,
      anchorDate: null,
      brokenStreakValue: data.current > 0
          ? data.current
          : data.brokenStreakValue,
      brokenAtDate: today,
    );
  }

  /// Whether a paid repair is still on offer for the last break.
  static bool isRepairAvailable(
    StreakData data,
    DateTime today, {
    required int windowHours,
  }) {
    if ((data.brokenStreakValue ?? 0) <= 0 || data.brokenAtDate == null) {
      return false;
    }
    final windowDays = (windowHours / 24).ceil();
    return _days(data.brokenAtDate!, today) <= windowDays;
  }

  /// Restores a broken streak to its pre-break value (paid repair).
  static StreakData repair(StreakData data, DateTime today) {
    final restore = data.brokenStreakValue ?? 0;
    return data.copyWith(
      current: restore,
      best: restore > data.best ? restore : data.best,
      anchorDate: _dayBefore(today),
      brokenStreakValue: null,
      brokenAtDate: null,
    );
  }

  /// Adds purchased freezes (capped at [maxSlots]).
  static StreakData addFreeze(StreakData data, {required int maxSlots}) {
    final next = (data.freezes + 1).clamp(0, maxSlots);
    return data.copyWith(freezes: next);
  }
}
