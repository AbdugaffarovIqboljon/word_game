import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Thin wrapper over `flutter_local_notifications` for the single streak
/// reminder. No FCM in v1 — everything is local and scheduled on-device.
///
/// The reminder fires at 20:00 in `Asia/Tashkent` — the game already rolls the
/// daily word over at Tashkent midnight (UTC+5, no DST) and the audience is
/// single-timezone, so this is the correct "local evening" without pulling in a
/// device-timezone dependency.
class NotificationService {
  NotificationService([FlutterLocalNotificationsPlugin? plugin])
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const int _reminderId = 1001;
  static const String _channelId = 'streak_reminder';

  bool _ready = false;

  /// Initialises the plugin + timezone db. Safe to call once at launch; never
  /// throws (a failure just leaves notifications inert).
  Future<void> init() async {
    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Tashkent'));
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _plugin.initialize(settings: settings);
      _ready = true;
    } catch (e) {
      if (kDebugMode) debugPrint('Notifications unavailable: $e');
    }
  }

  /// Requests the OS notification permission (Android 13+ / iOS). Called at
  /// onboarding completion, not at app start.
  Future<bool> requestPermission() async {
    if (!_ready) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
    }
    return false;
  }

  /// Schedules the reminder for the next 20:00 (today if still upcoming, else
  /// tomorrow). Idempotent — replaces any pending reminder.
  Future<void> scheduleStreakReminder({required int streak}) async {
    if (!_ready) return;
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20);
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));

    // uz-Latn only in v1 (ru / uz-Cyrl are disabled), so the copy is inlined.
    const title = "🔥 So'z Jangi";
    final body =
        '$streak kunlik streak kutmoqda — bugungi soʻzni toping!';

    try {
      await _plugin.zonedSchedule(
        id: _reminderId,
        title: title,
        body: body,
        scheduledDate: when,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Streak eslatmalari',
            channelDescription: 'Kunlik soʻzni eslatib turadi',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('scheduleStreakReminder failed: $e');
    }
  }

  Future<void> cancelStreakReminder() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(id: _reminderId);
    } catch (_) {}
  }
}
