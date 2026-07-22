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
import '../../../core/game/presentation/skin_background.dart';
import '../../../core/game/presentation/tile_skin.dart';
import '../../../core/game/presentation/widgets/game_keyboard.dart';
import '../../../core/game/presentation/widgets/invalid_word_toast.dart';
import '../../../core/game/presentation/widgets/known_letters_strip.dart';
import '../../../core/game/presentation/widgets/responsive_game_board.dart';
import '../../../core/l10n/locale_keys.dart';
import '../../../core/services/app_haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/time/game_clock.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/confetti_overlay.dart';
import '../../../core/widgets/counter_chip.dart';
import '../../../data/dictionary_datasource.dart';
import '../../ads/domain/reward_gateway.dart';
import '../../hints/domain/hint_type.dart';
import '../../hints/presentation/definition_hint_dialog.dart';
import '../../hints/presentation/hint_sheet.dart';
import '../../onboarding/presentation/widgets/rules_legend.dart';
import '../../shop/data/purchases_repository.dart';
import '../../shop/data/skin_service.dart';
import '../../wallet/data/wallet_service.dart';
import 'practice_cubit.dart';
import 'practice_state.dart';
import 'tier_presentation.dart';
import 'widgets/practice_overlay.dart';
import 'widgets/practice_theme_banner.dart';

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
        analytics: sl(),
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
    // The BlocConsumer listener misses the initial state, and start() emits
    // synchronously during creation — so set the board up from the current state
    // now (renders the locked first letter immediately, not after the first tap).
    _sync(_cubit.state);
  }

  void _onInput() {
    _board.setInput(_cubit.currentRow, _cubit.input.value);
    _board.setCursor(_cubit.currentRow, _cubit.input.value.length);
  }

  void _sync(PracticeState s) {
    if (s.roundNonce != _lastRound) {
      _lastRound = s.roundNonce;
      _board.clear();
      _board.setLockedPrefix(_cubit.lockedPrefix); // WS4
      _rendered = 0;
      _prevPhase = null;
      // Render the locked first letter on the active (first) row only.
      _board.setInput(0, _cubit.input.value);
      _board.setCursor(0, _cubit.input.value.length);
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
      dictionaryAvailable: _cubit.hasDefinition,
      revealAdAvailable: reward.isReady(RewardedPlacement.hintLetter).value,
      cleanAdAvailable: reward.isReady(RewardedPlacement.hintClean).value,
      cleanAvailable: _cubit.canCleanKeyboard,
      onBuy: (type, {required viaAd}) => _buyHint(type, viaAd: viaAd),
    );
  }

  Future<bool> _buyHint(HintType type, {required bool viaAd}) async {
    final config = sl<GameConfig>();
    final reward = sl<RewardGateway>();
    final price = switch (type) {
      HintType.revealLetter => config.hintRevealPrice,
      HintType.cleanKeyboard => config.hintCleanPrice,
      HintType.dictionary => config.hintDictionaryPrice,
    };
    Future<bool> pay() => viaAd
        ? reward.showRewardedAd(switch (type) {
            HintType.revealLetter => RewardedPlacement.hintLetter,
            HintType.cleanKeyboard => RewardedPlacement.hintClean,
            HintType.dictionary => RewardedPlacement.hintLetter, // no ad path
          })
        : _wallet.debitCoins(price, reason: 'hint_${type.name}');

    if (type == HintType.cleanKeyboard) {
      return _cubit.purchaseCleanKeyboard(
        pay: pay,
        refund: viaAd
            ? () async {}
            : () => _wallet.creditCoins(price, reason: 'hint_clean_refund'),
      );
    }

    // Lugʻat: charge only after the themed definition dialog displays; refund on
    // failure (WS1 req c/d). Most practice words have no definition, so the card
    // is hidden and this path is unreachable for them.
    if (type == HintType.dictionary) {
      return _cubit.purchaseDefinition(
        pay: pay,
        refund: () => _wallet.creditCoins(price, reason: 'hint_dictionary_refund'),
        reveal: _showDefinitionDialog,
      );
    }

    if (!await pay()) return false;
    if (type == HintType.revealLetter) _cubit.revealLetter();
    return true;
  }

  Future<bool> _showDefinitionDialog(String definition) async {
    if (!mounted) return false;
    await showAppDialog<void>(
      context,
      child: DefinitionHintDialog(definition: definition),
    );
    return true;
  }

  /// Atomic re-expand of the collapsed theme chip: coins when affordable,
  /// otherwise the existing rewarded-ad fallback surface.
  Future<bool> _reexpandTheme(Future<bool> Function() show) {
    final config = sl<GameConfig>();
    final reward = sl<RewardGateway>();
    final cost = config.hintThemeReexpandCost;
    final viaAd = _wallet.coins.value < cost;
    Future<bool> pay() => viaAd
        ? reward.showRewardedAd(RewardedPlacement.hintTheme)
        : _wallet.debitCoins(cost, reason: 'practice_theme_reexpand');
    return _cubit.purchaseThemeReexpand(
      pay: pay,
      refund: viaAd
          ? () async {}
          : () => _wallet.creditCoins(cost,
              reason: 'practice_theme_reexpand_refund'),
      show: show,
    );
  }

  /// Post-round "Yana" (WS1): free rounds replay immediately; once the daily
  /// allotment is spent, an [PracticeRoundMode.ad] tap watches a rewarded ad and
  /// only replays on completion (no interstitial stacked on top).
  Future<void> _again(PracticeRoundMode mode) async {
    if (mode == PracticeRoundMode.ad) {
      final earned = await sl<RewardGateway>()
          .showRewardedAd(RewardedPlacement.practiceExtra);
      if (earned) await _cubit.again(skipInterstitial: true);
    } else {
      await _cubit.again();
    }
  }

  /// "Keyingi daraja" — same free/ad gating as [_again] (WS1): advancing a tier
  /// also consumes a round, so it can't sidestep the ladder.
  Future<void> _nextTier(PracticeRoundMode mode) async {
    if (mode == PracticeRoundMode.ad) {
      final earned = await sl<RewardGateway>()
          .showRewardedAd(RewardedPlacement.practiceExtra);
      if (earned) await _cubit.nextTier(skipInterstitial: true);
    } else {
      await _cubit.nextTier();
    }
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
                        onRules: () => showRulesSheet(context),
                        onHint: state.phase == PracticePhase.playing
                            ? _openHint
                            : null,
                      ),
                      _PracticeContext(
                        tier: state.tier,
                        round: _cubit.sessionRound,
                      ),
                      if (state.phase == PracticePhase.playing &&
                          _cubit.hasTheme) ...[
                        const SizedBox(height: AppSpacing.s3),
                        PracticeThemeBanner(
                          theme: _cubit.theme,
                          roundNonce: state.roundNonce,
                          reexpandCost: sl<GameConfig>().hintThemeReexpandCost,
                          initialSeconds:
                              sl<GameConfig>().hintThemeInitialSeconds,
                          reexpandSeconds:
                              sl<GameConfig>().hintThemeReexpandSeconds,
                          onReexpand: _reexpandTheme,
                        ),
                        const SizedBox(height: AppSpacing.s4),
                      ],
                      Expanded(
                        child: ValueListenableBuilder<String>(
                          valueListenable: _skins.activeSkinId,
                          builder: (context, id, _) {
                            final skin = TileSkin.byId(id);
                            return SkinBackground(
                              skin: skin,
                              child: TileSkinScope(
                                skin: skin,
                                child: Column(
                                  children: [
                                    KnownLettersStrip(keyStates: _keyStates),
                                    Expanded(
                                      child: ResponsiveGameBoard(
                                        controller: _board,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      GameKeyboard(
                        keyStates: _keyStates,
                        cleanPulse: _cubit.cleanPulse,
                        onLetter: _cubit.addLetter,
                        onEnter: _cubit.submit,
                        onDelete: _cubit.removeLetter,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                if (state.phase != PracticePhase.playing)
                  ValueListenableBuilder<bool>(
                    valueListenable: sl<RewardGateway>()
                        .isReady(RewardedPlacement.practiceExtra),
                    builder: (context, adReady, _) {
                      final mode = _cubit.nextRoundIsFree
                          ? PracticeRoundMode.free
                          : (adReady
                              ? PracticeRoundMode.ad
                              : PracticeRoundMode.exhausted);
                      return PracticeOverlay(
                        solved: state.phase == PracticePhase.solved,
                        tier: state.tier,
                        reward: state.reward,
                        answer: state.answer,
                        definition: state.answerDefinition,
                        mode: mode,
                        onAgain: () => _again(mode),
                        onNextTier:
                            isHardest ? null : () => _nextTier(mode),
                        onBack: () => context.pop(),
                      );
                    },
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
    required this.onRules,
    required this.onHint,
  });

  final ValueListenable<int> coins;
  final VoidCallback onBack;
  final VoidCallback onRules;
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
          const SizedBox(width: 8),
          // Rules (?) consolidated into the top bar alongside the hint (WS3).
          AppIconButton(
            icon: AppIcons.help,
            onPressed: onRules,
            tooltip: LocaleKeys.commonRules.tr(),
          ),
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
