import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// The 10-role type scale (`decisions.md` §1). Space Grotesk everywhere except
/// [body] and [caption] (Manrope). All weights are 700-max — the spec's "800"
/// resolves to 700 (decisions §1).
///
/// Space Grotesk carries all display/title/numeral/tile roles; the [tile] role
/// defines weight+family only — its pixel size is supplied by the Tile widget
/// per size-context (56/52/42/30).
abstract final class AppTextStyles {
  const AppTextStyles._();

  static TextStyle _grotesk({
    required double size,
    required FontWeight weight,
    Color color = AppColors.text,
    double? letterSpacing,
    double? height,
  }) => GoogleFonts.spaceGrotesk(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );

  static TextStyle _manrope({
    required double size,
    required FontWeight weight,
    Color color = AppColors.text,
    double? height,
  }) => GoogleFonts.manrope(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );

  static TextStyle get display =>
      _grotesk(size: 44, weight: FontWeight.w700);

  static TextStyle get headline =>
      _grotesk(size: 32, weight: FontWeight.w700);

  static TextStyle get title => _grotesk(size: 26, weight: FontWeight.w700);

  static TextStyle get sectionTitle =>
      _grotesk(size: 20, weight: FontWeight.w700);

  static TextStyle get navTitle => _grotesk(size: 17, weight: FontWeight.w700);

  static TextStyle get bodyStrong =>
      _grotesk(size: 15, weight: FontWeight.w700);

  static TextStyle get body =>
      _manrope(size: 15, weight: FontWeight.w500, color: AppColors.text2);

  static TextStyle get caption =>
      _manrope(size: 13, weight: FontWeight.w500, color: AppColors.text3);

  static TextStyle get micro => _grotesk(
    size: 11,
    weight: FontWeight.w600,
    color: AppColors.text3,
    letterSpacing: 0.14 * 11,
    height: 1,
  );

  /// Tile letter. [size] is context-driven (28 gameplay / 26 onboarding /
  /// 21 fail / 15 recap). Uppercase, line-height 1, Space Grotesk 700.
  static TextStyle tile(double size, {Color color = AppColors.text}) =>
      _grotesk(size: size, weight: FontWeight.w700, color: color, height: 1);
}
