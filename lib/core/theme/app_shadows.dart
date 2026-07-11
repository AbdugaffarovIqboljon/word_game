import 'package:flutter/painting.dart';

/// Elevation / shadow tokens (`design_tokens.md` §5) plus the two structural
/// shadows formalized in `decisions.md` §5: [keyBevel] and [ctaGlow].
abstract final class AppShadows {
  const AppShadows._();

  /// e1 · card
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x66000000), offset: Offset(0, 1), blurRadius: 2),
  ];

  /// e2 · popover
  static const List<BoxShadow> popover = [
    BoxShadow(color: Color(0x80000000), offset: Offset(0, 4), blurRadius: 14),
  ];

  /// e3 · modal
  static const List<BoxShadow> modal = [
    BoxShadow(color: Color(0x99000000), offset: Offset(0, 16), blurRadius: 40),
  ];

  /// Upward-facing bottom-sheet shadow.
  static const List<BoxShadow> sheetUp = [
    BoxShadow(color: Color(0x99000000), offset: Offset(0, -16), blurRadius: 40),
  ];

  /// Invalid-word toast pill.
  static const List<BoxShadow> toast = [
    BoxShadow(color: Color(0x80000000), offset: Offset(0, 6), blurRadius: 18),
  ];

  /// Flat "bevel" bottom edge under every keyboard key (decisions §5).
  static const List<BoxShadow> keyBevel = [
    BoxShadow(color: Color(0x59000000), offset: Offset(0, 2)),
  ];

  /// Coin-reward badge glow.
  static const List<BoxShadow> coinGlow = [
    BoxShadow(color: Color(0x66F2C14E), offset: Offset(0, 8), blurRadius: 20),
  ];

  /// Raised colored-glow recipe under primary CTAs (decisions §5). Flutter has
  /// no inset shadow; the inset top-highlight is done as a gradient overlay in
  /// the button widget — these are the real drop layers.
  static List<BoxShadow> ctaGlow(Color brand) => [
    BoxShadow(
      color: brand.withValues(alpha: 0.58),
      offset: const Offset(0, 10),
      blurRadius: 24,
      spreadRadius: -8,
    ),
    const BoxShadow(color: Color(0x59000000), offset: Offset(0, 2), blurRadius: 6),
  ];
}
