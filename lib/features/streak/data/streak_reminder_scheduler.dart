import '../../../core/services/notification_service.dart';
import '../../settings/data/settings_service.dart';
import 'streak_repository.dart';

/// Policy for the single daily streak reminder. Keeps the reminder in sync with
/// the daily's solved-state and the Settings toggle:
///  * scheduled at 20:00 only while today's puzzle is still playable (unsolved),
///  * cancelled the moment it is solved/failed,
///  * fully gated by the notifications toggle (default on).
///
/// Called from presentation seams (daily page state, settings toggle, onboarding
/// completion) so no gameplay/domain code changes.
class StreakReminderScheduler {
  StreakReminderScheduler({
    required NotificationService notifications,
    required SettingsService settings,
    required StreakRepository streakRepo,
  })  : _notifications = notifications,
        _settings = settings,
        _streakRepo = streakRepo;

  final NotificationService _notifications;
  final SettingsService _settings;
  final StreakRepository _streakRepo;

  /// Today's daily is unsolved and still has attempts: (re)schedule if enabled.
  Future<void> reminderForPlayable(int streak) {
    if (!_settings.notifications.value) {
      return _notifications.cancelStreakReminder();
    }
    return _notifications.scheduleStreakReminder(streak: streak);
  }

  /// Today's daily is resolved (solved or failed) — nothing to remind about.
  Future<void> reminderResolved() => _notifications.cancelStreakReminder();

  /// Settings toggle flipped OFF by the user, or the manual re-schedule path.
  Future<void> onNotificationsToggled(bool enabled) {
    if (!enabled) return _notifications.cancelStreakReminder();
    return _notifications.scheduleStreakReminder(
      streak: _streakRepo.load().current,
    );
  }

  /// The post-solve "Ha, eslat" path: request the OS permission (the first and
  /// only time it is asked automatically), and schedule the reminder if granted.
  /// Returns whether permission is now granted.
  Future<bool> requestAndSchedule() async {
    final granted = await _notifications.requestPermission();
    if (granted && _settings.notifications.value) {
      await _notifications.scheduleStreakReminder(
        streak: _streakRepo.load().current,
      );
    }
    return granted;
  }

  /// Whether the OS currently grants notification permission (Settings toggle
  /// uses this to detect an OS denial).
  Future<bool> hasOsPermission() => _notifications.hasPermission();
}
