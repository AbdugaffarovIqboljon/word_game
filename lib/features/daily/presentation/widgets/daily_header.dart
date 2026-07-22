import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/counter_chip.dart';
import '../../../../core/widgets/streak_chip.dart';

/// Daily top bar (decisions §2 — no nav shell, chips ARE the navigation):
/// streak chip → streak, coin/gem chips → shop, bar-chart-3 → stats, gift →
/// chest, then the consolidated rules (?) and hint (💡) actions, and settings
/// (WS3). Icon order: stats · gift · ? · 💡 · settings. The chip group lives in
/// a horizontal scroll so it compresses before the icon buttons ever crowd at
/// 360px; every gap uses the same [AppSpacing.s2].
class DailyHeader extends StatelessWidget {
  const DailyHeader({
    required this.streak,
    required this.coins,
    required this.gems,
    required this.chestUnclaimed,
    required this.onStreak,
    required this.onShop,
    required this.onStats,
    required this.onChest,
    required this.onRules,
    required this.onSettings,
    this.onHint,
    this.rulesButtonKey,
    this.hintButtonKey,
    super.key,
  });

  final int streak;
  final ValueListenable<int> coins;
  final ValueListenable<int> gems;
  final bool chestUnclaimed;
  final VoidCallback onStreak;
  final VoidCallback onShop;
  final VoidCallback onStats;
  final VoidCallback onChest;
  final VoidCallback onRules;
  final VoidCallback onSettings;

  /// Present only while a puzzle is playable (WS3); otherwise the 💡 is hidden.
  final VoidCallback? onHint;

  /// Optional spotlight-tour anchors for the rules/hint icon buttons.
  final Key? rulesButtonKey;
  final Key? hintButtonKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                StreakChip(streak: streak, onTap: onStreak),
                const SizedBox(width: AppSpacing.s2),
                CoinChip(balance: coins, onTap: onShop),
                const SizedBox(width: AppSpacing.s2),
                GemChip(balance: gems, onTap: onShop),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s2),
        AppIconButton(icon: AppIcons.stats, onPressed: onStats),
        const SizedBox(width: AppSpacing.s2),
        AppIconButton(
          icon: AppIcons.gift,
          onPressed: onChest,
          dot: chestUnclaimed,
        ),
        const SizedBox(width: AppSpacing.s2),
        AppIconButton(
          key: rulesButtonKey,
          icon: AppIcons.help,
          onPressed: onRules,
          tooltip: LocaleKeys.commonRules.tr(),
        ),
        if (onHint != null) ...[
          const SizedBox(width: AppSpacing.s2),
          AppIconButton(
            key: hintButtonKey,
            icon: AppIcons.hint,
            iconColor: AppColors.fire,
            onPressed: onHint!,
          ),
        ],
        const SizedBox(width: AppSpacing.s2),
        AppIconButton(icon: AppIcons.settings, onPressed: onSettings),
      ],
    );
  }
}
