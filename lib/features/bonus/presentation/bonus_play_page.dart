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
import '../../../core/time/game_clock.dart';
import '../../../core/services/app_haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_icon_button.dart';
import '../../../core/widgets/confetti_overlay.dart';
import '../../../core/widgets/counter_chip.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../data/dictionary_datasource.dart';
import '../../ads/domain/reward_gateway.dart';
import '../../hints/domain/hint_type.dart';
import '../../hints/presentation/definition_hint_dialog.dart';
import '../../hints/presentation/hint_sheet.dart';
import '../../shop/data/skin_service.dart';
import '../../wallet/data/wallet_service.dart';
import 'bonus_cubit.dart';
import 'bonus_state.dart';
import 'widgets/bonus_overlay.dart';

/// Bonus ("Yana yechish") round (WS3): the daily board layout reused for a pro
/// user's extra words, with full hint support and a solved/failed overlay.
class BonusPlayPage extends StatelessWidget {
  const BonusPlayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BonusCubit>(
      create: (_) => BonusCubit(
        dictionary: sl(),
        pool: _fullPool,
        config: sl(),
        wallet: sl(),
        statsRepo: sl(),
        playedRepo: sl(),
        clock: sl<GameClock>(),
        analytics: sl(),
      )..start(),
      child: const BonusPlayView(),
    );
  }

  static List<List<LogicalLetter>> _fullPool() {
    final dict = sl<SupabaseAssetDictionary>();
    return [
      for (final tier in PracticeTier.values) ...dict.answersForTier(tier),
    ];
  }
}

class BonusPlayView extends StatefulWidget {
  const BonusPlayView({super.key});

  @override
  State<BonusPlayView> createState() => _BonusPlayViewState();
}

class _BonusPlayViewState extends State<BonusPlayView> {
  late final BonusCubit _cubit = context.read<BonusCubit>();
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
  BonusPhase? _prevPhase;

  @override
  void initState() {
    super.initState();
    _cubit.input.addListener(_onInput);
    // The BlocConsumer listener misses the initial state, and start() emits
    // synchronously during creation — set the board up from the current state now
    // so the locked first letter shows immediately, not after the first tap.
    _sync(_cubit.state);
  }

  void _onInput() {
    _board.setInput(_cubit.currentRow, _cubit.input.value);
    _board.setCursor(_cubit.currentRow, _cubit.input.value.length);
  }

  void _sync(BonusState s) {
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
    if (_prevPhase == BonusPhase.playing && s.phase == BonusPhase.solved) {
      _board.setCursor(-1, -1);
      _board.bounceRow(s.guesses.length - 1);
      _confetti.value++;
      AppHaptics.medium();
    } else if (_prevPhase == BonusPhase.playing && s.phase == BonusPhase.failed) {
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
            HintType.dictionary => RewardedPlacement.hintLetter,
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
        child: BlocConsumer<BonusCubit, BonusState>(
          listener: (context, state) => _sync(state),
          buildWhen: (a, b) =>
              a.phase != b.phase ||
              a.roundNonce != b.roundNonce ||
              a.reward != b.reward,
          builder: (context, state) {
            if (state.phase == BonusPhase.empty) return _EmptyState();
            return Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _BonusHeader(
                        coins: _wallet.coins,
                        onBack: () => context.pop(),
                        onHint: state.phase == BonusPhase.playing
                            ? _openHint
                            : null,
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
                        cleanPulse: _cubit.cleanPulse,
                        onLetter: _cubit.addLetter,
                        onEnter: _cubit.submit,
                        onDelete: _cubit.removeLetter,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                if (state.phase == BonusPhase.solved ||
                    state.phase == BonusPhase.failed)
                  BonusOverlay(
                    solved: state.phase == BonusPhase.solved,
                    reward: state.reward,
                    answer: state.answer,
                    definition: state.answerDefinition,
                    onAgain: _cubit.start,
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

class _BonusHeader extends StatelessWidget {
  const _BonusHeader({
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
          const SizedBox(width: 8),
          Text(LocaleKeys.bonusTitle.tr(), style: AppTextStyles.navTitle),
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

/// Shown when every bonus word has been played — nothing left to serve.
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(AppIcons.sparkles, size: 40, color: AppColors.coin),
          const SizedBox(height: 16),
          Text(
            LocaleKeys.bonusEmpty.tr(),
            textAlign: TextAlign.center,
            style: AppTextStyles.title,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: LocaleKeys.commonBack.tr(),
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }
}
