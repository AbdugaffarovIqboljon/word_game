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
import '../../../core/theme/app_text_styles.dart';
import '../../../core/time/game_clock.dart';
import '../../ads/domain/reward_gateway.dart';
import '../../hints/domain/hint_type.dart';
import '../../hints/presentation/hint_sheet.dart';
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
import 'widgets/chest_dialog.dart';
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
  final GameClock _clock = sl<GameClock>();
  final WalletService _wallet = sl<WalletService>();
  final SkinService _skins = sl<SkinService>();
  bool _resultAdShown = false;
  DailyPhase? _reminderPhase;

  int _rendered = 0;
  bool _restored = false;
  int _lastShake = 0;
  bool _checkedPending = false;

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

  void _onInput() => _board.setInput(_cubit.currentRow, _cubit.input.value);

  void _sync(DailyState s) {
    if (!_checkedPending && s.phase != DailyPhase.loading) {
      _checkedPending = true;
      _maybeFreezeConsumedDialog();
    }
    if (!_restored) {
      for (var r = 0; r < s.guesses.length; r++) {
        _board.restoreRow(r, s.guesses[r]);
      }
      _rendered = s.guesses.length;
      _restored = true;
    } else if (s.guesses.length > _rendered) {
      for (var r = _rendered; r < s.guesses.length; r++) {
        _board.revealRow(r, s.guesses[r]);
      }
      _rendered = s.guesses.length;
    }

    if (s.shakeSignal != _lastShake) {
      _lastShake = s.shakeSignal;
      _board.shakeRow(_cubit.currentRow);
      if (s.invalidWord) {
        InvalidWordToast.show(
          context,
          message: LocaleKeys.dailyInvalidWord.tr(),
        );
      }
    }

    // Result interstitial (sj_result_inter): fired once when the daily resolves.
    // The gateway caps it to 1/day and honours the session warm-up, so reopening
    // an already-solved daily right after launch never shows it.
    if (!_resultAdShown &&
        (s.phase == DailyPhase.solved || s.phase == DailyPhase.failed)) {
      _resultAdShown = true;
      sl<RewardGateway>().showInterstitial(InterstitialPlacement.result);
    }

    // Streak reminder: keep the 20:00 nudge in sync with today's solved-state.
    // Only act on phase transitions so typing doesn't reschedule every keystroke.
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
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
                    onHint: state.phase == DailyPhase.playing ? _openHint : null,
                  ),
                  Expanded(child: _body(state)),
                ],
              );
            },
          ),
        ),
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
        return SolvedRecap(
          guesses: state.guesses,
          attemptsUsed: state.attemptsUsed,
          maxAttempts: _cubit.maxAttempts,
          coinsEarned: state.reward?.total ?? 0,
          remaining: _remaining,
          onShare: () => _openShare(state),
        );
      case DailyPhase.failed:
        return FailView(
          guesses: state.guesses,
          answer: state.answer,
          definition: state.answerDefinition,
          remaining: _remaining,
          onShare: () => _openShare(state),
        );
      case DailyPhase.playing:
        return Column(
          children: [
            const SizedBox(height: 6),
            Text(LocaleKeys.dailySubtitle.tr(), style: AppTextStyles.caption),
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
}
