import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_icon_button.dart';
import '../../../../core/widgets/counter_chip.dart';
import '../../../../core/widgets/streak_chip.dart';

/// Daily top bar (decisions §2 — no nav shell, chips ARE the navigation):
/// streak chip → streak, coin/gem chips → shop, bar-chart-3 → stats, gift →
/// chest, hint (playing only) → hint sheet, settings → settings.
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
    this.onHint,
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

  /// Present only while a puzzle is in progress (dropped on solved/failed).
  final VoidCallback? onHint;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                StreakChip(streak: streak, onTap: onStreak),
                const SizedBox(width: 6),
                CoinChip(balance: coins, onTap: onShop),
                const SizedBox(width: 6),
                GemChip(balance: gems, onTap: onShop),
              ],
            ),
          ),
        ),
        const SizedBox(width: 6),
        AppIconButton(icon: AppIcons.stats, onPressed: onStats),
        const SizedBox(width: 6),
        AppIconButton(
          icon: AppIcons.gift,
          onPressed: onChest,
          dot: chestUnclaimed,
        ),
        if (onHint != null) ...[
          const SizedBox(width: 6),
          AppIconButton(
            icon: AppIcons.hint,
            onPressed: onHint!,
            iconColor: AppColors.fire, // amber hint tint
          ),
        ],
        const SizedBox(width: 6),
        AppIconButton(icon: AppIcons.settings, onPressed: onSettings),
      ],
    );
  }
}
