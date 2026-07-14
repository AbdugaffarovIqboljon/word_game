import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/primary_button.dart';

/// Shown in place of the daily board when today's puzzle metadata couldn't be
/// fetched from the backend (offline/5xx) — retry-friendly, never a crash.
class DailyLoadErrorView extends StatelessWidget {
  const DailyLoadErrorView({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              LocaleKeys.dailyLoadErrorTitle.tr(),
              textAlign: TextAlign.center,
              style: AppTextStyles.sectionTitle,
            ),
            const SizedBox(height: 8),
            Text(
              LocaleKeys.dailyLoadErrorBody.tr(),
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: AppColors.textSub),
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: LocaleKeys.commonRetry.tr(), onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
