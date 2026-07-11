import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/countdown_text.dart';

/// "Next word in HH:MM:SS" card shown on the solved & failed states.
class NextWordBox extends StatelessWidget {
  const NextWordBox({required this.remaining, this.compact = false, super.key});

  final Duration Function() remaining;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(AppIcons.clock, size: 15, color: AppColors.text3),
              const SizedBox(width: 6),
              Text(LocaleKeys.dailyNextWordIn.tr(), style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: 6),
          CountdownText(
            remaining: remaining,
            style: AppTextStyles.headline.copyWith(
              fontSize: compact ? 24 : 32,
            ),
          ),
        ],
      ),
    );
  }
}
