import 'dart:async';

import 'package:flutter/services.dart';

/// Lightweight haptics hook callable from decoupled core widgets (the keyboard,
/// the board) without a DI dependency. [enabled] is kept in sync by the settings
/// service, so every entry point here respects the haptics toggle in one place.
abstract final class AppHaptics {
  static bool enabled = true;

  /// Per-keystroke tick (key press).
  static void tap() {
    if (enabled) HapticFeedback.selectionClick();
  }

  /// Light confirmation (letter accepted).
  static void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  /// Win / positive resolution.
  static void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  /// Loss / soft "no" — two quick light ticks.
  static void doubleTick() {
    if (!enabled) return;
    HapticFeedback.lightImpact();
    Timer(const Duration(milliseconds: 90), () {
      if (enabled) HapticFeedback.lightImpact();
    });
  }
}
