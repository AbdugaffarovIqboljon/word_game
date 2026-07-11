import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/config/game_config.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/l10n/locale_keys.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/time/game_clock.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/nav_header.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../ads/domain/reward_gateway.dart';
import '../../wallet/data/wallet_service.dart';
import '../data/streak_history_repository.dart';
import '../data/streak_repository.dart';
import '../domain/streak_calculator.dart';
import '../domain/streak_data.dart';
import 'widgets/streak_dialogs.dart';

/// Streak & Freeze detail (screen_inventory §7): hero, 30-day heat row, freeze
/// inventory + buy, and the repair offer when broken.
class StreakPage extends StatefulWidget {
  const StreakPage({super.key});

  @override
  State<StreakPage> createState() => _StreakPageState();
}

class _StreakPageState extends State<StreakPage> {
  final StreakRepository _repo = sl<StreakRepository>();
  final StreakHistoryRepository _history = sl<StreakHistoryRepository>();
  final GameConfig _config = sl<GameConfig>();
  final GameClock _clock = sl<GameClock>();
  final WalletService _wallet = sl<WalletService>();
  final RewardGateway _ads = sl<RewardGateway>();

  late StreakData _streak = _repo.load();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOfferRepair());
  }

  Future<void> _maybeOfferRepair() async {
    if (!mounted) return;
    final today = _clock.puzzleDate();
    if (!StreakCalculator.isRepairAvailable(
      _streak,
      today,
      windowHours: _config.streakRepairWindowHours,
    )) {
      return;
    }
    final repair = await showStreakRepairDialog(
      context,
      brokenValue: _streak.brokenStreakValue ?? 0,
      gemPrice: _config.streakRepairGemPrice,
      remaining: _repairRemaining,
    );
    if (repair != true) return;
    final paid = await _wallet.debitGems(
      _config.streakRepairGemPrice,
      reason: 'streak_repair',
    );
    if (!paid) return;
    setState(() {
      _streak = StreakCalculator.repair(_streak, today);
    });
    await _repo.save(_streak);
  }

  Duration _repairRemaining() {
    final brokenAt = _streak.brokenAtDate;
    if (brokenAt == null) return Duration.zero;
    final deadline = brokenAt.add(Duration(hours: _config.streakRepairWindowHours));
    return deadline.difference(_clock.nowUtc());
  }

  Future<void> _buyFreeze({required bool viaAd}) async {
    if (_streak.freezes >= _config.freezeSlots) return;
    final paid = viaAd
        ? await _ads.showRewardedAd()
        : await _wallet.debitCoins(
            _config.freezeBuyPriceCoins,
            reason: 'buy_freeze',
          );
    if (!paid) return;
    setState(() {
      _streak = StreakCalculator.addFreeze(_streak, maxSlots: _config.freezeSlots);
    });
    await _repo.save(_streak);
  }

  @override
  Widget build(BuildContext context) {
    final days = _history.lastDays(_clock.puzzleDate());
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            NavHeader(title: LocaleKeys.streakNavTitle.tr()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _HeroCard(current: _streak.current, best: _streak.best),
                  const SizedBox(height: 20),
                  _HeatRow(days: days),
                  const SizedBox(height: 20),
                  Text(LocaleKeys.streakFreezeTitle.tr(), style: AppTextStyles.sectionTitle),
                  const SizedBox(height: 12),
                  _FreezeInventory(
                    filled: _streak.freezes,
                    slots: _config.freezeSlots,
                  ),
                  const SizedBox(height: 16),
                  if (_streak.freezes < _config.freezeSlots)
                    _BuyFreezeCard(
                      coinPrice: _config.freezeBuyPriceCoins,
                      onBuyCoins: () => _buyFreeze(viaAd: false),
                      onBuyAd: () => _buyFreeze(viaAd: true),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatefulWidget {
  const _HeroCard({required this.current, required this.best});
  final int current;
  final int best;

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.current > 0) _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.current > 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.correct.withValues(alpha: 0.14),
        borderRadius: AppRadii.cardR,
        border: Border.all(color: AppColors.correct.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          ScaleTransition(
            scale: Tween<double>(begin: 1, end: 1.12).animate(
              CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
            ),
            child: Icon(
              AppIcons.flame,
              size: 48,
              color: active ? AppColors.fire : AppColors.muted,
            ),
          ),
          const SizedBox(height: 12),
          Text('${widget.current}', style: AppTextStyles.display),
          const SizedBox(height: 4),
          Text(
            LocaleKeys.streakPersonalBest.tr(namedArgs: {'best': '${widget.best}'}),
            style: AppTextStyles.caption.copyWith(color: AppColors.textSub),
          ),
        ],
      ),
    );
  }
}

class _HeatRow extends StatelessWidget {
  const _HeatRow({required this.days});
  final List<DayStatus> days;

  Color _colorFor(DayStatus s) => switch (s) {
    DayStatus.played => AppColors.correct,
    DayStatus.frozen => AppColors.gem,
    DayStatus.missed => AppColors.danger.withValues(alpha: 0.5),
    DayStatus.empty => AppColors.surface2,
    DayStatus.future => AppColors.surface,
  };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final status in days)
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: _colorFor(status),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}

class _FreezeInventory extends StatelessWidget {
  const _FreezeInventory({required this.filled, required this.slots});
  final int filled;
  final int slots;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < slots; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: _FreezeSlot(filled: i < filled)),
        ],
      ],
    );
  }
}

class _FreezeSlot extends StatelessWidget {
  const _FreezeSlot({required this.filled});
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.cardR,
        border: Border.all(
          color: filled ? AppColors.gem.withValues(alpha: 0.5) : AppColors.border,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            filled ? AppIcons.snowflake : AppIcons.plus,
            size: 22,
            color: filled ? AppColors.gem : AppColors.muted,
          ),
          const SizedBox(height: 6),
          Text(
            filled
                ? LocaleKeys.streakFreezeReady.tr()
                : LocaleKeys.streakFreezeEmpty.tr(),
            style: AppTextStyles.caption.copyWith(
              color: filled ? AppColors.text2 : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _BuyFreezeCard extends StatelessWidget {
  const _BuyFreezeCard({
    required this.coinPrice,
    required this.onBuyCoins,
    required this.onBuyAd,
  });

  final int coinPrice;
  final VoidCallback onBuyCoins;
  final VoidCallback onBuyAd;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(LocaleKeys.streakFreezeGet.tr(), style: AppTextStyles.bodyStrong),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: '$coinPrice',
                  icon: AppIcons.coins,
                  onPressed: onBuyCoins,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SecondaryButton(
                  label: LocaleKeys.hintWatchAd.tr(),
                  icon: AppIcons.watchAd,
                  onPressed: onBuyAd,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
