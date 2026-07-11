import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/game_config.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/game/domain/letter_result.dart';
import '../../../core/game/domain/logical_letter.dart';
import '../../../core/game/presentation/board_controller.dart';
import '../../../core/game/presentation/tile_skin.dart';
import '../../../core/game/presentation/widgets/game_board.dart';
import '../../../core/game/presentation/widgets/game_keyboard.dart';
import '../../../core/game/presentation/widgets/invalid_word_toast.dart';
import '../../../core/l10n/locale_keys.dart';
import '../../../core/services/app_haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/time/game_clock.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/confetti_overlay.dart';
import '../../../core/widgets/counter_chip.dart';
import '../../../data/dictionary_datasource.dart';
import '../../ads/domain/reward_gateway.dart';
import '../../hints/domain/hint_type.dart';
import '../../hints/presentation/hint_sheet.dart';
import '../../shop/data/purchases_repository.dart';
import '../../shop/data/skin_service.dart';
import '../../wallet/data/wallet_service.dart';
import 'practice_cubit.dart';
import 'practice_state.dart';
import 'tier_presentation.dart';
import 'widgets/practice_overlay.dart';

class PracticePlayPage extends StatelessWidget {
  const PracticePlayPage({required this.tier, super.key});

  final PracticeTier tier;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PracticeCubit>(
      create: (_) => PracticeCubit(
        tier: tier,
        dictionary: sl(),
        answersForTier: sl<SupabaseAssetDictionary>().answersForTier,
        config: sl(),
        wallet: sl(),
        rewardGateway: sl(),
        clock: sl<GameClock>(),
        repository: sl(),
        removeAds: sl<PurchasesRepository>().removeAds.value,
      )..start(tier),
      child: const PracticePlayView(),
    );
  }
}

class PracticePlayView extends StatefulWidget {
  const PracticePlayView({super.key});

  @override
  State<PracticePlayView> createState() => _PracticePlayViewState();
}

class _PracticePlayViewState extends State<PracticePlayView> {
  late final PracticeCubit _cubit = context.read<PracticeCubit>();
  late final BoardController _board = BoardController(
    rows: _cubit.maxAttempts,
    columns: _cubit.wordLength,
  );
  final ValueNotifier<Map<LogicalLetter, LetterResult>> _keyStates =
      ValueNotifier(const {});
  final ValueNotifier<int> _confetti = ValueNotifier(0);
  final WalletService _wallet = sl<WalletService>();
  final SkinService _skins = sl<SkinService>();

  int _rendered = 0;
  int _lastShake = 0;
  int _lastRound = 0;
  PracticePhase? _prevPhase;

  @override
  void initState() {
    super.initState();
    _cubit.input.addListener(_onInput);
  }

  void _onInput() {
    _board.setInput(_cubit.currentRow, _cubit.input.value);
    _board.setCursor(_cubit.currentRow, _cubit.input.value.length);
  }

  void _sync(PracticeState s) {
    if (s.roundNonce != _lastRound) {
      _lastRound = s.roundNonce;
      _board.clear();
      _rendered = 0;
      _prevPhase = null;
      _board.setCursor(0, 0);
    }
    if (s.guesses.length > _rendered) {
      for (var r = _rendered; r < s.guesses.length; r++) {
        _board.revealRow(r, s.guesses[r]);
      }
      _rendered = s.guesses.length;
    }
    if (s.shakeSignal != _lastShake) {
      _lastShake = s.shakeSignal;
      _board.shakeRow(_cubit.currentRow);
      AppHaptics.light();
      InvalidWordToast.show(
        context,
        message: (s.invalidWord
                ? LocaleKeys.dailyInvalidWord
                : LocaleKeys.dailyTooShort)
            .tr(),
      );
    }
    // Win/loss choreography on a fresh transition from playing.
    if (_prevPhase == PracticePhase.playing &&
        s.phase == PracticePhase.solved) {
      _board.setCursor(-1, -1);
      _board.bounceRow(s.guesses.length - 1);
      _confetti.value++;
      AppHaptics.medium();
    } else if (_prevPhase == PracticePhase.playing &&
        s.phase == PracticePhase.failed) {
      AppHaptics.doubleTick();
    }
    _prevPhase = s.phase;
    _keyStates.value = s.keyStates;
  }

  void _openHint() {
    final config = sl<GameConfig>();
    final reward = sl<RewardGateway>();
    showHintSheet(
      context,
      coinBalance: _wallet.coins,
      revealPrice: config.hintRevealPrice,
      cleanPrice: config.hintCleanPrice,
      dictionaryPrice: config.hintDictionaryPrice,
      definition: _cubit.definition,
      revealAdAvailable: reward.isReady(RewardedPlacement.hintLetter).value,
      cleanAdAvailable: reward.isReady(RewardedPlacement.hintClean).value,
      onBuy: (type, {required viaAd}) async {
        final price = switch (type) {
          HintType.revealLetter => config.hintRevealPrice,
          HintType.cleanKeyboard => config.hintCleanPrice,
          HintType.dictionary => config.hintDictionaryPrice,
        };
        final paid = viaAd
            ? await reward.showRewardedAd(switch (type) {
                HintType.revealLetter => RewardedPlacement.hintLetter,
                HintType.cleanKeyboard => RewardedPlacement.hintClean,
                HintType.dictionary => RewardedPlacement.hintLetter, // no ad path
              })
            : await _wallet.debitCoins(price, reason: 'hint_${type.name}');
        if (!paid) return false;
        switch (type) {
          case HintType.revealLetter:
            _cubit.revealLetter();
          case HintType.cleanKeyboard:
            _cubit.cleanKeyboard();
          case HintType.dictionary:
            break;
        }
        return true;
      },
    );
  }

  @override
  void dispose() {
    _cubit.input.removeListener(_onInput);
    _board.dispose();
    _keyStates.dispose();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<PracticeCubit, PracticeState>(
          listener: (context, state) => _sync(state),
          buildWhen: (a, b) =>
              a.phase != b.phase ||
              a.roundNonce != b.roundNonce ||
              a.tier != b.tier ||
              a.reward != b.reward,
          builder: (context, state) {
            final isHardest = state.tier == PracticeTier.values.last;
            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _Header(
                        coins: _wallet.coins,
                        onBack: () => context.pop(),
                        onHint: state.phase == PracticePhase.playing
                            ? _openHint
                            : null,
                      ),
                      _PracticeContext(
                        tier: state.tier,
                        round: _cubit.sessionRound,
                      ),
                      Expanded(
                        child: Center(
                          child: ValueListenableBuilder<String>(
                            valueListenable: _skins.activeSkinId,
                            builder: (context, id, _) => TileSkinScope(
                              skin: TileSkin.byId(id),
                              child: GameBoard(controller: _board),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GameKeyboard(
                        keyStates: _keyStates,
                        onLetter: _cubit.addLetter,
                        onEnter: _cubit.submit,
                        onDelete: _cubit.removeLetter,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                if (state.phase != PracticePhase.playing)
                  PracticeOverlay(
                    solved: state.phase == PracticePhase.solved,
                    tier: state.tier,
                    reward: state.reward,
                    answer: state.answer,
                    definition: state.answerDefinition,
                    onAgain: _cubit.again,
                    onNextTier: isHardest ? null : _cubit.nextTier,
                    onBack: () => context.pop(),
                  ),
                ConfettiOverlay(trigger: _confetti),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.coins,
    required this.onBack,
    required this.onHint,
  });

  final ValueListenable<int> coins;
  final VoidCallback onBack;
  final VoidCallback? onHint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          AppIconButton(icon: AppIcons.back, onPressed: onBack),
          const Spacer(),
          CoinChip(balance: coins),
          if (onHint != null) ...[
            const SizedBox(width: 8),
            AppIconButton(
              icon: AppIcons.hint,
              iconColor: AppColors.fire,
              onPressed: onHint!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Practice context block (mandate B2/PG-1): tier badge + round counter, the
/// practice analogue of the daily board's puzzle-number header.
class _PracticeContext extends StatelessWidget {
  const _PracticeContext({required this.tier, required this.round});

  final PracticeTier tier;
  final int round;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          _TierBadge(tier: tier),
          const Spacer(),
          Text(
            LocaleKeys.practiceRoundLabel.tr(namedArgs: {'n': '$round'}),
            style: AppTextStyles.caption.copyWith(color: AppColors.textSub),
          ),
        ],
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier});

  final PracticeTier tier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: tier.accent.withValues(alpha: 0.16),
        borderRadius: AppRadii.pillR,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tier.icon, size: 15, color: tier.accent),
          const SizedBox(width: 7),
          Text(
            tier.nameKey.tr(),
            style: AppTextStyles.bodyStrong.copyWith(
              fontSize: 14,
              color: tier.accent,
            ),
          ),
        ],
      ),
    );
  }
}
