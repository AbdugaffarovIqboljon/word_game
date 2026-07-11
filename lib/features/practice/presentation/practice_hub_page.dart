import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/game_config.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/l10n/locale_keys.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/time/game_clock.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/counter_chip.dart';
import '../../../core/widgets/nav_header.dart';
import '../../wallet/data/wallet_service.dart';
import '../data/practice_repository.dart';
import '../domain/practice_session.dart';
import 'tier_presentation.dart';

/// Practice Hub (screen_inventory §3): tier picker + today's session stats +
/// interstitial-ad notice.
class PracticeHubPage extends StatelessWidget {
  const PracticeHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final config = sl<GameConfig>();
    final wallet = sl<WalletService>();
    final session = sl<PracticeRepository>().loadFor(sl<GameClock>().puzzleDate());

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            NavHeader(
              title: LocaleKeys.practiceNavTitle.tr(),
              trailing: CoinChip(
                balance: wallet.coins,
                onTap: () => context.push(AppRoutes.shop),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  for (final tier in PracticeTier.values) ...[
                    TierCard(
                      tier: tier,
                      reward: config.practiceReward(tier),
                      onTap: () => context.pushNamed(
                        AppRoutes.practicePlayName,
                        extra: tier,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                  SessionRow(session: session),
                  const SizedBox(height: 16),
                  const AdNotice(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TierCard extends StatelessWidget {
  const TierCard({
    required this.tier,
    required this.reward,
    required this.onTap,
    super.key,
  });

  final PracticeTier tier;
  final int reward;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tier.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(tier.icon, size: 22, color: tier.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(tier.nameKey.tr(), style: AppTextStyles.sectionTitle),
          ),
          Row(
            children: [
              const Icon(AppIcons.coins, size: 15, color: AppColors.coin),
              const SizedBox(width: 6),
              Text(
                LocaleKeys.practiceTierReward.tr(namedArgs: {'count': '$reward'}),
                style: AppTextStyles.bodyStrong.copyWith(color: AppColors.coin),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SessionRow extends StatelessWidget {
  const SessionRow({required this.session, super.key});

  final PracticeSession session;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(LocaleKeys.practiceSessionTitle.tr(), style: AppTextStyles.bodyStrong),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SessionStat(
                  value: '${session.solved}',
                  label: LocaleKeys.practiceSessionSolved.tr(),
                ),
              ),
              Expanded(
                child: SessionStat(
                  value: '${session.accuracyPercent}%',
                  label: LocaleKeys.practiceSessionAccuracy.tr(),
                ),
              ),
              Expanded(
                child: SessionStat(
                  value: '${session.coins}',
                  label: LocaleKeys.practiceSessionCoins.tr(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SessionStat extends StatelessWidget {
  const SessionStat({required this.value, required this.label, super.key});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: AppTextStyles.sectionTitle),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSub),
        ),
      ],
    );
  }
}

class AdNotice extends StatelessWidget {
  const AdNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gem.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gem.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.info, size: 16, color: AppColors.gem),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              LocaleKeys.practiceAdNotice.tr(),
              style: AppTextStyles.caption.copyWith(color: AppColors.text2),
            ),
          ),
        ],
      ),
    );
  }
}
