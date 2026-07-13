import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/game/domain/guess.dart';
import '../../../../core/game/presentation/widgets/static_board.dart';
import '../../../../core/l10n/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/primary_button.dart';
import 'next_word_box.dart';

/// Daily solved state (screen_inventory 1d): sparkles, "Ajoyib!", attempt
/// subtitle, 30px recap board, next-word countdown, Telegram share CTA, and the
/// coins-earned line.
class SolvedRecap extends StatelessWidget {
  const SolvedRecap({
    required this.guesses,
    required this.attemptsUsed,
    required this.maxAttempts,
    required this.coinsEarned,
    required this.remaining,
    required this.onShare,
    this.onElapsed,
    this.banner,
    this.bonusAction,
    super.key,
  });

  final List<Guess> guesses;
  final int attemptsUsed;
  final int maxAttempts;
  final int coinsEarned;
  final Duration Function() remaining;
  final VoidCallback onShare;
  final VoidCallback? onElapsed;

  /// Optional card rendered above the recap (the notification pre-permission
  /// prompt, WS2).
  final Widget? banner;

  /// Optional "Yana yechish" bonus action (WS3), rendered below the coins line.
  final Widget? bonusAction;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          if (banner != null) ...[
            banner!,
            const SizedBox(height: 20),
          ],
          const Icon(AppIcons.sparkles, size: 40, color: AppColors.coin),
          const SizedBox(height: 12),
          Text(LocaleKeys.dailySolvedHeadline.tr(), style: AppTextStyles.title),
          const SizedBox(height: 6),
          Text(
            LocaleKeys.dailySolvedAttempts.tr(
              namedArgs: {'attempts': '$attemptsUsed', 'max': '$maxAttempts'},
            ),
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 20),
          StaticBoard(guesses: guesses, columns: 5, tileSize: 30),
          const SizedBox(height: 20),
          NextWordBox(remaining: remaining, onElapsed: onElapsed),
          const SizedBox(height: 16),
          PrimaryButton(
            label: LocaleKeys.dailyShareResult.tr(),
            variant: PrimaryButtonVariant.telegram,
            icon: AppIcons.telegram,
            onPressed: onShare,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(AppIcons.coins, size: 15, color: AppColors.coin),
              const SizedBox(width: 6),
              Text(
                LocaleKeys.dailyCoinsEarned.tr(
                  namedArgs: {'count': '$coinsEarned'},
                ),
                style: AppTextStyles.bodyStrong.copyWith(
                  fontSize: 14,
                  color: AppColors.successBright,
                ),
              ),
            ],
          ),
          if (bonusAction != null) ...[
            const SizedBox(height: 20),
            bonusAction!,
          ],
        ],
      ),
    );
  }
}
