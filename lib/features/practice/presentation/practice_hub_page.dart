import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/game_config.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/l10n/locale_keys.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/time/game_clock.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/counter_chip.dart';
import '../../../core/widgets/nav_header.dart';
import '../../ads/domain/reward_gateway.dart';
import '../../shop/data/purchases_repository.dart';
import '../../wallet/data/wallet_service.dart';
import '../data/practice_repository.dart';
import '../domain/practice_session.dart';
import 'tier_presentation.dart';
import 'widgets/practice_overlay.dart';

/// Practice Hub (screen_inventory §3): tier picker + today's session stats +
/// interstitial-ad notice.
///
/// WS5: the "Bugungi sessiya" row is bound to [PracticeRepository.current], so it
/// updates live on each game end and — via the [loadFor] on entry / route return
/// — resets at Tashkent midnight, all without an app restart.
class PracticeHubPage extends StatefulWidget {
  const PracticeHubPage({super.key});

  @override
  State<PracticeHubPage> createState() => _PracticeHubPageState();
}

class _PracticeHubPageState extends State<PracticeHubPage> {
  PracticeRepository get _repo => sl<PracticeRepository>();
  GameClock get _clock => sl<GameClock>();
  RewardGateway get _ads => sl<RewardGateway>();
  PurchasesRepository get _purchases => sl<PurchasesRepository>();
  GameConfig get _config => sl<GameConfig>();

  @override
  void initState() {
    super.initState();
    _repo.loadFor(_clock.puzzleDate()); // sync today's session into the notifier
  }

  Future<void> _play(PracticeTier tier) async {
    await context.pushNamed(AppRoutes.practicePlayName, extra: tier);
    // Refresh on return so a midnight rollover resets the session numbers.
    if (mounted) _repo.loadFor(_clock.puzzleDate());
  }

  /// Free rounds are spent — watch a rewarded ad for one extra round (WS1). The
  /// round itself is counted by the play page's `start()`, so nothing is
  /// consumed if the ad is dismissed.
  Future<void> _playViaAd(PracticeTier tier) async {
    final earned =
        await _ads.showRewardedAd(RewardedPlacement.practiceExtra);
    if (earned && mounted) await _play(tier);
  }

  /// No free rounds and no ad to fill — invite the player back tomorrow.
  void _showExhausted() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            LocaleKeys.practiceRoundsExhausted.tr(
              namedArgs: {'max': '${_config.practiceFreeRoundsPerDay}'},
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = sl<WalletService>();
    final free = _config.practiceFreeRoundsPerDay;

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
              // Rebuild the ladder whenever the entitlement inputs change: the
              // session counter (free rounds spent), the pro flag, and whether a
              // rewarded ad is currently fillable (WS1).
              child: ValueListenableBuilder<bool>(
                valueListenable: _purchases.removeAds,
                builder: (context, isPro, _) => ValueListenableBuilder<bool>(
                  valueListenable:
                      _ads.isReady(RewardedPlacement.practiceExtra),
                  builder: (context, adReady, _) =>
                      ValueListenableBuilder<PracticeSession>(
                    valueListenable: _repo.current,
                    builder: (context, session, _) {
                      final remaining =
                          (free - session.started).clamp(0, free);
                      final mode = isPro || remaining > 0
                          ? PracticeRoundMode.free
                          : (adReady
                              ? PracticeRoundMode.ad
                              : PracticeRoundMode.exhausted);
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        children: [
                          FreeRoundsBadge(
                            isPro: isPro,
                            remaining: remaining,
                            total: free,
                          ),
                          const SizedBox(height: 12),
                          for (final tier in PracticeTier.values) ...[
                            TierCard(
                              tier: tier,
                              reward: _config.practiceReward(tier),
                              mode: mode,
                              onTap: switch (mode) {
                                PracticeRoundMode.free => () => _play(tier),
                                PracticeRoundMode.ad => () => _playViaAd(tier),
                                PracticeRoundMode.exhausted => _showExhausted,
                              },
                            ),
                            const SizedBox(height: 12),
                          ],
                          const SizedBox(height: 8),
                          SessionRow(session: session),
                          const SizedBox(height: 16),
                          AdNotice(freeRounds: free),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Remaining free practice rounds today, or the "Cheksiz" pro badge (WS1).
class FreeRoundsBadge extends StatelessWidget {
  const FreeRoundsBadge({
    required this.isPro,
    required this.remaining,
    required this.total,
    super.key,
  });

  final bool isPro;
  final int remaining;
  final int total;

  @override
  Widget build(BuildContext context) {
    final color = isPro ? AppColors.coin : AppColors.textSub;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: AppRadii.pillR,
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPro ? AppIcons.sparkles : AppIcons.practice,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              isPro
                  ? LocaleKeys.practiceUnlimited.tr()
                  : LocaleKeys.practiceFreeRemaining.tr(
                      namedArgs: {'n': '$remaining', 'max': '$total'},
                    ),
              style: AppTextStyles.bodyStrong.copyWith(color: color),
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
    required this.mode,
    required this.onTap,
    super.key,
  });

  final PracticeTier tier;
  final int reward;
  final PracticeRoundMode mode;
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
          // Free rounds show the coin reward; once spent the button reads as a
          // rewarded-ad offer instead (WS1).
          if (mode == PracticeRoundMode.free)
            Row(
              children: [
                const Icon(AppIcons.coins, size: 15, color: AppColors.coin),
                const SizedBox(width: 6),
                Text(
                  LocaleKeys.practiceTierReward
                      .tr(namedArgs: {'count': '$reward'}),
                  style:
                      AppTextStyles.bodyStrong.copyWith(color: AppColors.coin),
                ),
              ],
            )
          else
            const Icon(AppIcons.watchAd, size: 18, color: AppColors.gem),
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
  const AdNotice({required this.freeRounds, super.key});

  final int freeRounds;

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
              LocaleKeys.practiceAdNotice.tr(namedArgs: {'max': '$freeRounds'}),
              style: AppTextStyles.caption.copyWith(color: AppColors.text2),
            ),
          ),
        ],
      ),
    );
  }
}
