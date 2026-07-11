import 'package:easy_localization/easy_localization.dart';
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
import '../../../core/router/app_routes.dart';
import '../../../core/services/app_haptics.dart';
import '../../../core/time/game_clock.dart';
import '../../../core/widgets/confetti_overlay.dart';
import '../../ads/domain/reward_gateway.dart';
import '../../hints/domain/hint_type.dart';
import '../../hints/presentation/hint_sheet.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/presentation/widgets/rules_legend.dart';
import '../../shop/data/skin_service.dart';
import '../../streak/data/streak_reminder_scheduler.dart';
import '../../streak/data/streak_repository.dart';
import '../../streak/domain/streak_calculator.dart';
import '../../streak/presentation/widgets/streak_dialogs.dart';
import '../../wallet/data/wallet_service.dart';
import '../data/daily_chest_repository.dart';
import '../domain/daily_share_data.dart';
import 'daily_cubit.dart';
import 'daily_state.dart';
import 'widgets/board_ghost_hint.dart';
import 'widgets/chest_dialog.dart';
import 'widgets/daily_context_header.dart';
import 'widgets/daily_header.dart';
import 'widgets/fail_view.dart';
import 'widgets/mashq_pill.dart';
import 'widgets/solved_recap.dart';

class DailyPage extends StatelessWidget {
  const DailyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DailyCubit>(
      create: (_) => sl<DailyCubit>()..load(),
      child: const DailyView(),
    );
  }
}

/// The Daily Board screen — one route, five visual states driven by
/// [DailyState.phase] (screen_inventory §1). Owns the [BoardController] and the
/// keyboard-state notifier so typing/reveal never rebuild the whole tree.
class DailyView extends StatefulWidget {
  const DailyView({super.key});

  @override
  State<DailyView> createState() => _DailyViewState();
}

class _DailyViewState extends State<DailyView> {
  late final DailyCubit _cubit = context.read<DailyCubit>();
  late final BoardController _board = BoardController(
    rows: _cubit.maxAttempts,
    columns: _cubit.wordLength,
  );
  final ValueNotifier<Map<LogicalLetter, LetterResult>> _keyStates =
      ValueNotifier(const {});
  final ValueNotifier<int> _confetti = ValueNotifier(0);
  final GameClock _clock = sl<GameClock>();
  final WalletService _wallet = sl<WalletService>();
  final SkinService _skins = sl<SkinService>();
  bool _resultAdShown = false;
  DailyPhase? _reminderPhase;
  DailyPhase? _prevPhase;
  bool _celebrating = false;

  int _rendered = 0;
  bool _restored = false;
  int _lastShake = 0;
  bool _checkedPending = false;
  bool _checkedRules = false;

  @override
  void initState() {
    super.initState();
    _cubit.input.addListener(_onInput);
  }

  Future<void> _maybeFreezeConsumedDialog() async {
    final outcome = await sl<StreakRepository>().takePendingOutcome();
    if (!mounted) return;
    if (outcome == StreakOutcome.savedByFreeze) {
      await showFreezeConsumedDialog(context);
    }
  }

  /// Auto-open the rules sheet the first time a skipper reaches the board
  /// (decisions / mandate B3).
  void _maybeAutoOpenRules(DailyState s) {
    if (s.phase != DailyPhase.playing) return;
    final onboarding = sl<OnboardingRepository>();
    if (onboarding.hasSeenRules || onboarding.hasAutoShownRules) return;
    onboarding.markRulesAutoShown();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showRulesSheet(context);
    });
  }

  void _onInput() {
    _board.setInput(_cubit.currentRow, _cubit.input.value);
    _board.setCursor(_cubit.currentRow, _cubit.input.value.length);
  }

  void _sync(DailyState s) {
    if (!_checkedPending && s.phase != DailyPhase.loading) {
      _checkedPending = true;
      _maybeFreezeConsumedDialog();
    }
    if (!_checkedRules && s.phase != DailyPhase.loading) {
      _checkedRules = true;
      _maybeAutoOpenRules(s);
    }
    if (!_restored) {
      for (var r = 0; r < s.guesses.length; r++) {
        _board.restoreRow(r, s.guesses[r]);
      }
      _rendered = s.guesses.length;
      _restored = true;
      if (s.phase == DailyPhase.playing) {
        _board.setCursor(_cubit.currentRow, 0);
      }
    } else if (s.guesses.length > _rendered) {
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

    // Result interstitial (sj_result_inter): fired once when the daily resolves.
    if (!_resultAdShown &&
        (s.phase == DailyPhase.solved || s.phase == DailyPhase.failed)) {
      _resultAdShown = true;
      sl<RewardGateway>().showInterstitial(InterstitialPlacement.result);
    }

    // Win/loss choreography: only on a fresh transition from playing (never on a
    // restored, already-resolved board).
    if (_prevPhase == DailyPhase.playing && s.phase == DailyPhase.solved) {
      _runWinChoreography(s);
    } else if (_prevPhase == DailyPhase.playing &&
        s.phase == DailyPhase.failed) {
      AppHaptics.doubleTick();
    }
    _prevPhase = s.phase;

    // Streak reminder: keep the 20:00 nudge in sync with today's solved-state.
    if (_reminderPhase != s.phase && s.phase != DailyPhase.loading) {
      _reminderPhase = s.phase;
      final reminders = sl<StreakReminderScheduler>();
      if (s.phase == DailyPhase.playing) {
        reminders.reminderForPlayable(s.streak);
      } else {
        reminders.reminderResolved();
      }
    }

    _keyStates.value = s.keyStates;
  }

  /// Winning-row bounce → confetti → medium haptic, holding the board briefly so
  /// the celebration is seen before the recap replaces it (mandate B6).
  void _runWinChoreography(DailyState s) {
    _board.setCursor(-1, -1);
    _board.bounceRow(s.guesses.length - 1);
    _confetti.value++;
    AppHaptics.medium();
    setState(() => _celebrating = true);
    Future.delayed(const Duration(milliseconds: 950), () {
      if (mounted) setState(() => _celebrating = false);
    });
  }

  /// Daily rollover: rebuild for the new puzzle date without an app restart.
  void _reloadForNewDay() {
    setState(() {
      _board.clear();
      _rendered = 0;
      _restored = false;
      _resultAdShown = false;
      _reminderPhase = null;
      _prevPhase = null;
      _celebrating = false;
    });
    _cubit.load();
  }

  void _openShare(DailyState s) {
    context.pushNamed(
      AppRoutes.shareName,
      extra: DailyShareData(
        puzzleNumber: s.puzzleNumber,
        attemptsUsed: s.attemptsUsed,
        maxAttempts: _cubit.maxAttempts,
        streak: s.streak,
        guesses: s.guesses,
        solved: s.phase == DailyPhase.solved,
        reward: s.reward,
      ),
    );
  }

  Duration _remaining() => _clock.untilNextRollover();

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
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: BlocConsumer<DailyCubit, DailyState>(
                listener: (context, state) => _sync(state),
                buildWhen: (a, b) =>
                    a.phase != b.phase ||
                    a.guesses.length != b.guesses.length ||
                    a.streak != b.streak ||
                    a.chestUnclaimed != b.chestUnclaimed ||
                    a.reward != b.reward,
                builder: (context, state) {
                  return Column(
                    children: [
                      const SizedBox(height: 8),
                      DailyHeader(
                        streak: state.streak,
                        coins: _wallet.coins,
                        gems: _wallet.gems,
                        chestUnclaimed: state.chestUnclaimed,
                        onStreak: () => context.push(AppRoutes.streak),
                        onShop: () => context.push(AppRoutes.shop),
                        onStats: () => context.push(AppRoutes.stats),
                        onChest: _openChest,
                        onSettings: () => context.push(AppRoutes.settings),
                      ),
                      Expanded(child: _body(state)),
                    ],
                  );
                },
              ),
            ),
          ),
          ConfettiOverlay(trigger: _confetti),
        ],
      ),
    );
  }

  Future<void> _openChest() async {
    await showDailyChestDialog(
      context,
      config: sl<GameConfig>(),
      wallet: _wallet,
      rewardGateway: sl<RewardGateway>(),
      chestRepo: sl<DailyChestRepository>(),
      today: _cubit.today,
    );
    _cubit.refreshChestFlag();
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
            break; // the sheet reveals the definition itself
        }
        return true;
      },
    );
  }

  Widget _body(DailyState state) {
    switch (state.phase) {
      case DailyPhase.loading:
        return const Center(child: CircularProgressIndicator());
      case DailyPhase.solved:
        // Hold the board during the win choreography, then reveal the recap.
        if (_celebrating) return _playingBoard(state, interactive: false);
        return SolvedRecap(
          guesses: state.guesses,
          attemptsUsed: state.attemptsUsed,
          maxAttempts: _cubit.maxAttempts,
          coinsEarned: state.reward?.total ?? 0,
          remaining: _remaining,
          onShare: () => _openShare(state),
          onElapsed: _reloadForNewDay,
        );
      case DailyPhase.failed:
        return FailView(
          guesses: state.guesses,
          answer: state.answer,
          definition: state.answerDefinition,
          remaining: _remaining,
          onShare: () => _openShare(state),
          onElapsed: _reloadForNewDay,
        );
      case DailyPhase.playing:
        return _playingBoard(state, interactive: true);
    }
  }

  Widget _playingBoard(DailyState state, {required bool interactive}) {
    return Column(
      children: [
        const SizedBox(height: 8),
        DailyContextHeader(
          puzzleNumber: state.puzzleNumber,
          date: _cubit.today,
          onRules: () => showRulesSheet(context),
          onHint: interactive && state.phase == DailyPhase.playing
              ? _openHint
              : null,
        ),
        Expanded(
          child: Center(
            child: ValueListenableBuilder<String>(
              valueListenable: _skins.activeSkinId,
              builder: (context, id, _) => TileSkinScope(
                skin: TileSkin.byId(id),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    GameBoard(controller: _board),
                    BoardGhostHint(cursor: _board.cursor),
                  ],
                ),
              ),
            ),
          ),
        ),
        MashqPill(onTap: () => context.push(AppRoutes.practice)),
        const SizedBox(height: 12),
        GameKeyboard(
          keyStates: _keyStates,
          onLetter: _cubit.addLetter,
          onEnter: _cubit.submit,
          onDelete: _cubit.removeLetter,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
