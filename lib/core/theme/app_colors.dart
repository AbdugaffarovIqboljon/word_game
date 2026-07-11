import 'package:flutter/painting.dart';

/// Central color token layer for So'z Jangi.
///
/// Literal transcription of `design_tokens.md` reconciled with `decisions.md`.
/// The design-canvas color `#0A0C10` is deliberately absent — it is not an app
/// color (decisions §4).
abstract final class AppColors {
  const AppColors._();

  // ── Surfaces ──────────────────────────────────────────────────────────────
  static const Color bg = Color(0xFF0B1220);
  static const Color surface = Color(0xFF121C2E);
  static const Color surface2 = Color(0xFF1A2740);
  static const Color surface3 = Color(0xFF223152);
  static const Color surfaceModal = Color(0xFF0E1420); // decisions §4
  static const Color border = Color(0xFF2A3A5C);
  static const Color borderStrong = Color(0xFF3A4E78);

  // ── Tile states ───────────────────────────────────────────────────────────
  static const Color tileEmptyBorder = Color(0xFF2E3E60);
  static const Color tileFilledBg = Color(0xFF16233F);
  static const Color tileFilledBorder = Color(0xFF56688F);
  static const Color tileAbsentBg = Color(0xFF35435F);
  static const Color tileAbsentFg = Color(0xFFD5DDEC);
  // Active-position feedback: the live row's empty tiles brighten to this, and
  // the next-empty ("cursor") tile pulses between tileFilledBorder and this.
  static const Color tileActiveBorder = Color(0xFF41557E);
  static const Color tileCursorBorder = Color(0xFF7C90BC);

  // ── Shared present/correct (tile + key) ──────────────────────────────────
  static const Color present = Color(0xFFC2952B);
  static const Color onPresent = Color(0xFF0B1220);
  static const Color correct = Color(0xFF3E9B54);
  static const Color onCorrect = Color(0xFFFFFFFF);

  // ── Key states ────────────────────────────────────────────────────────────
  static const Color keyDefault = Color(0xFF3A4A6B);
  static const Color onKeyDefault = Color(0xFFF4F7FC);
  static const Color keyAbsentBg = Color(0xFF212D45);
  static const Color keyAbsentFg = Color(0xFF5E6D8C);

  // ── Accents ───────────────────────────────────────────────────────────────
  static const Color fire = Color(0xFFF5A623);
  static const Color coin = Color(0xFFF2C14E);
  static const Color goldBright = Color(0xFFF2CF6A);
  static const Color gem = Color(0xFF7BC8FF);
  static const Color telegram = Color(0xFF229ED9);
  static const Color danger = Color(0xFFE5484D);
  static const Color successBright = Color(0xFF5FBE73); // decisions §4

  // ── Text ──────────────────────────────────────────────────────────────────
  static const Color text = Color(0xFFF4F7FC);
  static const Color text2 = Color(0xFFA5B2CC);
  static const Color text3 = Color(0xFF6B7A99);
  static const Color textSub = Color(0xFF8493B0); // decisions §4
  static const Color divider = Color(0xFF1B2436);

  // ── Semantic / misc ───────────────────────────────────────────────────────
  static const Color muted = Color(0xFF4A5B80); // decisions §4 (ENTER/DEL, dim flame)
  static const Color onGold = Color(0xFF3A2A00); // decisions §4
  static const Color white = Color(0xFFFFFFFF);
  static const Color scrim = Color(0x99050E0E); // rgba(5,8,14,.6) dialog backdrop

  // Disabled / locked button palette (component_spec (c)).
  static const Color disabledBg = Color(0xFF131C2C);
  static const Color disabledBorder = Color(0xFF22304C);
  static const Color disabledFg = Color(0xFF5E6D8C);
}
