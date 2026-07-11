import 'package:flutter/foundation.dart';

import '../../../core/services/app_haptics.dart';
import '../../../core/storage/preferences_service.dart';

/// Persists user preferences (sound / haptics / notifications) and keeps the
/// decoupled [AppHaptics] flag in sync. Balances are reactive so toggles update
/// instantly. Notification scheduling / audio playback back-ends are later work
/// packages; the toggles are the durable source of truth they will read.
class SettingsService {
  SettingsService(this._prefs);

  static const _soundKey = 'set_sound';
  static const _hapticsKey = 'set_haptics';
  static const _notificationsKey = 'set_notifications';

  final PreferencesService _prefs;

  final ValueNotifier<bool> sound = ValueNotifier(true);
  final ValueNotifier<bool> haptics = ValueNotifier(true);
  final ValueNotifier<bool> notifications = ValueNotifier(true);

  void load() {
    sound.value = _prefs.getBool(_soundKey, fallback: true);
    haptics.value = _prefs.getBool(_hapticsKey, fallback: true);
    notifications.value = _prefs.getBool(_notificationsKey, fallback: true);
    AppHaptics.enabled = haptics.value;
  }

  Future<void> setSound(bool value) {
    sound.value = value;
    return _prefs.setBool(_soundKey, value);
  }

  Future<void> setHaptics(bool value) {
    haptics.value = value;
    AppHaptics.enabled = value;
    return _prefs.setBool(_hapticsKey, value);
  }

  Future<void> setNotifications(bool value) {
    notifications.value = value;
    return _prefs.setBool(_notificationsKey, value);
  }

  void dispose() {
    sound.dispose();
    haptics.dispose();
    notifications.dispose();
  }
}
