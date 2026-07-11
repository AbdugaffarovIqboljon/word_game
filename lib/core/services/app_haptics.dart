import 'package:flutter/services.dart';

/// Lightweight haptics hook callable from decoupled core widgets (the keyboard)
/// without a DI dependency. [enabled] is kept in sync by the settings service.
abstract final class AppHaptics {
  static bool enabled = true;

  static void tap() {
    if (enabled) HapticFeedback.selectionClick();
  }
}
