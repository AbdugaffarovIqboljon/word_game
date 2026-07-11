import 'package:flutter_test/flutter_test.dart';
import 'package:word_game/features/streak/domain/streak_calculator.dart';
import 'package:word_game/features/streak/domain/streak_data.dart';

DateTime d(int day) => DateTime.utc(2026, 1, day);

void main() {
  group('recordSolved', () {
    test('first ever solve → streak 1', () {
      final r = StreakCalculator.recordSolved(const StreakData(), d(5));
      expect(r.current, 1);
      expect(r.best, 1);
      expect(r.anchorDate, d(5));
      expect(r.lastSolvedDate, d(5));
    });

    test('consecutive day increments', () {
      var s = StreakCalculator.recordSolved(const StreakData(), d(5));
      s = StreakCalculator.reconcile(s, d(6)).data;
      s = StreakCalculator.recordSolved(s, d(6));
      expect(s.current, 2);
      expect(s.best, 2);
    });

    test('solving twice the same day is a no-op', () {
      var s = StreakCalculator.recordSolved(const StreakData(), d(5));
      s = StreakCalculator.recordSolved(s, d(5));
      expect(s.current, 1);
    });
  });

  group('reconcile — missed days', () {
    final base = StreakData(current: 3, best: 3, anchorDate: d(5));

    test('gap of one day stays intact', () {
      final r = StreakCalculator.reconcile(base, d(6));
      expect(r.outcome, StreakOutcome.none);
      expect(r.data.current, 3);
    });

    test('one missed day with no freeze → broken', () {
      final r = StreakCalculator.reconcile(base, d(7));
      expect(r.outcome, StreakOutcome.broken);
      expect(r.data.current, 0);
      expect(r.data.brokenStreakValue, 3);
      expect(r.data.brokenAtDate, d(7));
    });

    test('one missed day with a freeze → saved, freeze consumed', () {
      final withFreeze = base.copyWith(freezes: 1);
      final r = StreakCalculator.reconcile(withFreeze, d(7));
      expect(r.outcome, StreakOutcome.savedByFreeze);
      expect(r.freezesConsumed, 1);
      expect(r.data.freezes, 0);
      expect(r.data.current, 3);
      // Solving today then continues the streak.
      final solved = StreakCalculator.recordSolved(r.data, d(7));
      expect(solved.current, 4);
    });

    test('two missed days need two freezes', () {
      final oneFreeze = base.copyWith(freezes: 1);
      expect(
        StreakCalculator.reconcile(oneFreeze, d(8)).outcome,
        StreakOutcome.broken,
      );

      final twoFreezes = base.copyWith(freezes: 2);
      final r = StreakCalculator.reconcile(twoFreezes, d(8));
      expect(r.outcome, StreakOutcome.savedByFreeze);
      expect(r.freezesConsumed, 2);
      expect(r.data.freezes, 0);
    });

    test('reconcile is idempotent within the same day (no double charge)', () {
      final withFreeze = base.copyWith(freezes: 1);
      final first = StreakCalculator.reconcile(withFreeze, d(7)).data;
      final second = StreakCalculator.reconcile(first, d(7));
      expect(second.outcome, StreakOutcome.none);
      expect(second.data.freezes, 0); // not charged again
    });
  });

  group('fail + repair', () {
    test('failing today breaks the streak immediately', () {
      final s = StreakData(current: 5, best: 5, anchorDate: d(5));
      final r = StreakCalculator.recordFail(s, d(6));
      expect(r.current, 0);
      expect(r.brokenStreakValue, 5);
      expect(r.brokenAtDate, d(6));
    });

    test('repair restores within window then continues on solve', () {
      final broken = StreakData(
        current: 0,
        best: 5,
        brokenStreakValue: 5,
        brokenAtDate: d(6),
      );
      expect(
        StreakCalculator.isRepairAvailable(broken, d(6), windowHours: 48),
        isTrue,
      );
      final repaired = StreakCalculator.repair(broken, d(6));
      expect(repaired.current, 5);
      final solved = StreakCalculator.recordSolved(repaired, d(6));
      expect(solved.current, 6);
    });

    test('repair unavailable after the window', () {
      final broken = StreakData(
        brokenStreakValue: 5,
        brokenAtDate: d(6),
      );
      expect(
        StreakCalculator.isRepairAvailable(broken, d(9), windowHours: 48),
        isFalse,
      );
    });
  });

  group('freeze inventory cap', () {
    test('addFreeze respects max slots', () {
      var s = const StreakData(freezes: 1);
      s = StreakCalculator.addFreeze(s, maxSlots: 2);
      expect(s.freezes, 2);
      s = StreakCalculator.addFreeze(s, maxSlots: 2);
      expect(s.freezes, 2); // capped
    });
  });
}
