import 'package:flutter/widgets.dart';

import '../../../core/config/game_config.dart';
import '../../../core/l10n/locale_keys.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';

/// Per-tier display metadata (name key, accent color, icon).
extension TierPresentation on PracticeTier {
  String get nameKey => switch (this) {
    PracticeTier.easy => LocaleKeys.practiceTierEasy,
    PracticeTier.medium => LocaleKeys.practiceTierMedium,
    PracticeTier.hard => LocaleKeys.practiceTierHard,
  };

  Color get accent => switch (this) {
    PracticeTier.easy => AppColors.successBright,
    PracticeTier.medium => AppColors.coin,
    PracticeTier.hard => AppColors.danger,
  };

  IconData get icon => switch (this) {
    PracticeTier.easy => AppIcons.tierEasy,
    PracticeTier.medium => AppIcons.tierMedium,
    PracticeTier.hard => AppIcons.tierHard,
  };
}
