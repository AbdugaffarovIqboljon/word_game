import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/game_config.dart';
import '../../../../core/game/domain/logical_letter.dart';
import '../../../../core/l10n/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';

/// How the post-round "Yana" / "Keyingi daraja" CTAs behave (WS1):
/// [free] plays immediately, [ad] gates behind a rewarded ad, [exhausted] shows
/// the come-back-tomorrow message because no ad could fill.
enum PracticeRoundMode { free, ad, exhausted }

/// Track-A solved/failed overlay (decisions §8): a card over the board with the
/// result, reward and the again / next-tier / back actions.
class PracticeOverlay extends StatelessWidget {
  const PracticeOverlay({
    required this.solved,
    required this.tier,
    required this.reward,
    required this.answer,
    required this.definition,
    required this.mode,
    required this.onAgain,
    required this.onNextTier,
    required this.onBack,
    super.key,
  });

  final bool solved;
  final PracticeTier tier;
  final int reward;
  final List<LogicalLetter> answer;
  final String? definition;

  /// Free-round entitlement state for the CTAs (WS1).
  final PracticeRoundMode mode;

  final VoidCallback onAgain;
  final VoidCallback? onNextTier;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: AppColors.scrim,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: AppCard(
              shadow: true,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    solved ? AppIcons.sparkles : AppIcons.close,
                    size: 36,
                    color: solved ? AppColors.coin : AppColors.danger,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    solved
                        ? LocaleKeys.practiceSolvedOverlay.tr()
                        : LocaleKeys.practiceFailedOverlay.tr(),
                    style: AppTextStyles.title,
                  ),
                  const SizedBox(height: 6),
                  if (solved)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(AppIcons.coins, size: 15, color: AppColors.coin),
                        const SizedBox(width: 6),
                        Text(
                          '+$reward',
                          style: AppTextStyles.bodyStrong.copyWith(
                            color: AppColors.successBright,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    Text(
                      answer.map((l) => l.glyph).join(),
                      style: AppTextStyles.sectionTitle.copyWith(letterSpacing: 3),
                    ),
                    if (definition != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        definition!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSub,
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 20),
                  if (mode == PracticeRoundMode.exhausted) ...[
                    // No free rounds left and no ad to fill — invite them back
                    // tomorrow instead of an actionable "Yana" (WS1).
                    Text(
                      LocaleKeys.practiceRoundsExhausted.tr(),
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSub,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    PrimaryButton(
                      label: mode == PracticeRoundMode.ad
                          ? LocaleKeys.practiceWatchExtra.tr()
                          : LocaleKeys.practiceAgain.tr(),
                      icon: mode == PracticeRoundMode.ad
                          ? AppIcons.watchAd
                          : AppIcons.refresh,
                      onPressed: onAgain,
                    ),
                    if (solved && onNextTier != null) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: SecondaryButton(
                          label: LocaleKeys.practiceNextTier.tr(),
                          icon: mode == PracticeRoundMode.ad
                              ? AppIcons.watchAd
                              : AppIcons.chevronRight,
                          onPressed: onNextTier,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: SecondaryButton(
                      label: LocaleKeys.commonBack.tr(),
                      icon: AppIcons.back,
                      onPressed: onBack,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
