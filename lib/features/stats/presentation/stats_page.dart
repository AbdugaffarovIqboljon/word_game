import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/l10n/locale_keys.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/nav_header.dart';
import '../../streak/data/streak_repository.dart';
import '../data/stats_repository.dart';
import '../domain/stats_data.dart';

/// Stats (screen_inventory §5): 2×2 grid + guess-distribution histogram with the
/// most-recent attempt highlighted, plus a success callout.
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stats = sl<StatsRepository>().load();
    final streak = sl<StreakRepository>().load();
    final mode = _modeAttempt(stats);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            NavHeader(title: LocaleKeys.statsNavTitle.tr()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Row(
                    children: [
                      Expanded(child: StatTile(value: '${stats.played}', label: LocaleKeys.statsPlayed.tr())),
                      const SizedBox(width: 12),
                      Expanded(child: StatTile(value: '${stats.winRatePercent}', label: LocaleKeys.statsWinRate.tr())),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: StatTile(value: '${streak.current}', label: LocaleKeys.statsStreak.tr())),
                      const SizedBox(width: 12),
                      Expanded(child: StatTile(value: '${streak.best}', label: LocaleKeys.statsBest.tr())),
                    ],
                  ),
                  // WS3: bonus-word row, shown once the player has done a bonus.
                  if (stats.bonusPlayed > 0) ...[
                    const SizedBox(height: 20),
                    Text(LocaleKeys.statsBonusTitle.tr(), style: AppTextStyles.sectionTitle),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: StatTile(value: '${stats.bonusSolved}', label: LocaleKeys.statsBonusSolved.tr())),
                        const SizedBox(width: 12),
                        Expanded(child: StatTile(value: '${stats.bonusWinRatePercent}', label: LocaleKeys.statsBonusWinRate.tr())),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(LocaleKeys.statsDistribution.tr(), style: AppTextStyles.sectionTitle),
                  const SizedBox(height: 14),
                  for (var attempt = 1; attempt <= stats.distribution.length; attempt++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: HistogramRow(
                        attempt: attempt,
                        count: stats.distribution[attempt - 1],
                        maxCount: stats.maxInDistribution,
                        highlighted: stats.lastWinAttempt == attempt,
                      ),
                    ),
                  if (stats.lastWinAttempt != null && stats.lastWinAttempt == mode) ...[
                    const SizedBox(height: 12),
                    _SuccessNote(attempt: stats.lastWinAttempt!),
                  ],
                  const SizedBox(height: 28),
                  Center(
                    child: Text(
                      LocaleKeys.appTitle.tr(),
                      style: AppTextStyles.caption.copyWith(color: AppColors.text3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  int? _modeAttempt(StatsData stats) {
    if (stats.maxInDistribution == 0) return null;
    return stats.distribution.indexOf(stats.maxInDistribution) + 1;
  }
}

class StatTile extends StatelessWidget {
  const StatTile({required this.value, required this.label, super.key});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          Text(value, style: AppTextStyles.headline.copyWith(fontSize: 30)),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(color: AppColors.textSub),
          ),
        ],
      ),
    );
  }
}

class HistogramRow extends StatelessWidget {
  const HistogramRow({
    required this.attempt,
    required this.count,
    required this.maxCount,
    required this.highlighted,
    super.key,
  });

  final int attempt;
  final int count;
  final int maxCount;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final fraction = maxCount == 0 ? 0.0 : count / maxCount;
    final barColor = highlighted ? AppColors.correct : AppColors.tileAbsentBg;
    return Row(
      children: [
        SizedBox(
          width: 16,
          child: Text('$attempt', style: AppTextStyles.bodyStrong.copyWith(fontSize: 14)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fraction.clamp(0.12, 1.0),
              child: Container(
                height: 26,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.centerRight,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$count',
                  style: AppTextStyles.bodyStrong.copyWith(
                    fontSize: 13,
                    color: highlighted ? AppColors.onCorrect : AppColors.tileAbsentFg,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SuccessNote extends StatelessWidget {
  const _SuccessNote({required this.attempt});
  final int attempt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.correct.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.correct.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.check, size: 16, color: AppColors.successBright),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              LocaleKeys.statsSuccessNote.tr(namedArgs: {'attempt': '$attempt'}),
              style: AppTextStyles.caption.copyWith(color: AppColors.successBright),
            ),
          ),
        ],
      ),
    );
  }
}
