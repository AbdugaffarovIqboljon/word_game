import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';

/// Post-solve pre-permission card (WS2). Shown on the result screen after the
/// first daily solve to warm up the OS notification request: only "Ha, eslat"
/// triggers the actual OS prompt.
class NotificationPromptCard extends StatelessWidget {
  const NotificationPromptCard({
    required this.onAccept,
    required this.onLater,
    super.key,
  });

  final VoidCallback onAccept;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.surface2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            LocaleKeys.notifPromptTitle.tr(),
            style: AppTextStyles.bodyStrong.copyWith(color: AppColors.fire),
          ),
          const SizedBox(height: 4),
          Text(
            LocaleKeys.notifPromptBody.tr(),
            style: AppTextStyles.caption.copyWith(color: AppColors.textSub),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: LocaleKeys.notifPromptLater.tr(),
                  onPressed: onLater,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  label: LocaleKeys.notifPromptYes.tr(),
                  height: 46,
                  onPressed: onAccept,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
