import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_text_styles.dart';

/// Assembles the single dark [ThemeData] for the app. Individual widgets pull
/// from [AppColors] / [AppTextStyles] / [AppRadii] / [AppSpacing] / [AppShadows]
/// directly; this theme sets scaffold background, the color scheme, and maps the
/// 10 type roles onto Material's [TextTheme] slots for framework widgets.
abstract final class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.correct,
      onPrimary: AppColors.onCorrect,
      secondary: AppColors.telegram,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: AppColors.danger,
      onError: AppColors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg, // never #0A0C10 (decisions §4)
      canvasColor: AppColors.bg,
      splashFactory: InkRipple.splashFactory,
      textTheme: TextTheme(
        displayLarge: AppTextStyles.display,
        headlineLarge: AppTextStyles.headline,
        titleLarge: AppTextStyles.title,
        titleMedium: AppTextStyles.sectionTitle,
        titleSmall: AppTextStyles.navTitle,
        labelLarge: AppTextStyles.bodyStrong,
        bodyLarge: AppTextStyles.body,
        bodyMedium: AppTextStyles.body,
        bodySmall: AppTextStyles.caption,
        labelSmall: AppTextStyles.micro,
      ),
    );
  }
}
