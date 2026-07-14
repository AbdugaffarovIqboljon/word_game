import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/counter_chip.dart';
import '../../../../core/widgets/streak_chip.dart';

/// Daily top bar (decisions §2 — no nav shell, chips ARE the navigation):
/// streak chip → streak, coin/gem chips → shop, bar-chart-3 → stats, gift →
/// chest, settings → settings. The hint action moved to the board context
/// header so three chips + three icon buttons stay uncrowded down to 360px
/// width; every gap — inside the chip group and between the icon buttons —
/// uses the same [AppSpacing.s2] so nothing reads as clustered or spread out.
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
    required this.onSettings,
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
  final VoidCallback onSettings;

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
        AppIconButton(icon: AppIcons.settings, onPressed: onSettings),
      ],
    );
  }
}
