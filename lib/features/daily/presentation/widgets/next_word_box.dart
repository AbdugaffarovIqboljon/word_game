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
  const NextWordBox({
    required this.remaining,
    this.compact = false,
    this.onElapsed,
    super.key,
  });

  final Duration Function() remaining;
  final bool compact;

  /// Fired when the countdown reaches zero (daily rollover → refresh the board).
  final VoidCallback? onElapsed;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppIcons.clock, size: 15, color: AppColors.text3),
              const SizedBox(width: 6),
              // Flexible + ellipsis so the label can shrink instead of pushing
              // the row past the card at large text scales (WS2).
              Flexible(
                child: Text(
                  LocaleKeys.dailyNextWordIn.tr(),
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // The HH:MM:SS numerals are the widest element in the compact (half
          // width) fail-view slot; scale them down to fit rather than overflow
          // the card at 360px / fontScale 1.3 (WS2).
          FittedBox(
            fit: BoxFit.scaleDown,
            child: CountdownText(
              remaining: remaining,
              onElapsed: onElapsed,
              style: AppTextStyles.headline.copyWith(
                fontSize: compact ? 24 : 32,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
