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
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/confetti_overlay.dart';
import '../../../core/widgets/spotlight_tour.dart';
import '../../ads/domain/reward_gateway.dart';
import '../../bonus/presentation/widgets/bonus_button.dart';
import '../../hints/domain/hint_type.dart';
import '../../hints/presentation/definition_hint_dialog.dart';
import '../../hints/presentation/hint_sheet.dart';
import '../../notifications/data/notification_prompt_repository.dart';
import '../../notifications/domain/notification_prompt_policy.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/domain/daily_tour_step.dart';
import '../../onboarding/presentation/widgets/rules_legend.dart';
import '../../practice/presentation/widgets/practice_theme_banner.dart';
import '../../shop/data/purchases_repository.dart';
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
import 'widgets/daily_context_header.dart';
import 'widgets/daily_header.dart';
import 'widgets/daily_load_error_view.dart';
import 'widgets/fail_view.dart';
import 'widgets/mashq_pill.dart';
import 'widgets/notification_prompt_card.dart';
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
  // Single source of truth for the board's tile geometry, shared by
  // [GameBoard] and the spotlight tour so its board step targets the exact
  // rendered board rect.
  static const double _tileSize = 56;
  static const double _gap = 6;

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
  final NotificationPromptRepository _notifPrompts =
      sl<NotificationPromptRepository>();
  final OnboardingRepository _onboarding = sl<OnboardingRepository>();
  // Captured once: whether this is the user's first-ever real daily board (drives
  // the warmer ghost affordance, WS1).
  late final bool _firstDailyHint = !_onboarding.hasSeenFirstDailyHint;

  // Spotlight-tour anchors: top bar, help/hint icons, "Mashq" pill and the
  // board itself. Wired onto the real, already-rendered widgets below.
  final GlobalKey _headerKey = GlobalKey();
  final GlobalKey _helpKey = GlobalKey();
  final GlobalKey _hintKey = GlobalKey();
  final GlobalKey _mashqPillKey = GlobalKey();
  final GlobalKey _boardKey = GlobalKey();
  late final SpotlightTourController _tourController =
      SpotlightTourController(stepCount: DailyTourStep.values.length);

  bool _resultAdShown = false;
  bool _showNotifPrompt = false;
  DailyPhase? _reminderPhase;
  DailyPhase? _prevPhase;
  bool _celebrating = false;

  int _rendered = 0;
  bool _restored = false;
  int _lastShake = 0;
  int _lastNetworkError = 0;
  bool _checkedPending = false;
  bool _checkedRules = false;
  bool _checkedTour = false;

  @override
  void initState() {
    super.initState();
    _cubit.input.addListener(_onInput);
    _tourController.addListener(_onTourStep);
    // Show the first-ever affordance only once: persist immediately, keep it for
    // this session via the captured flag.
    if (_firstDailyHint) _onboarding.markFirstDailyHintSeen();

    // The BlocConsumer listener does not fire for the initial state, and load()
    // usually emits synchronously during creation — so render the board from the
    // current state now (frame 1), and run the full sync (dialogs, reminders,
    // interstitial) after the first frame is built.
    final s = _cubit.state;
    _restoreBoard(s);
    _keyStates.value = s.keyStates;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sync(_cubit.state);
    });
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
    _board.setInput(
      _cubit.currentRow,
      _cubit.input.value,
      lockedPositions: _cubit.lockedPositions,
      prefillPositions: _cubit.prefillPositions,
    );
    _board.setCursor(_cubit.currentRow, _cubit.input.value.length);
  }

  void _onLetter(LogicalLetter letter) {
    _cubit.addLetter(letter);
  }

  /// Starts the fresh-install spotlight tour the first time the board reaches
  /// [DailyPhase.playing] — i.e. the very first daily board the app has ever
  /// shown — and persists so it never runs again.
  void _maybeStartTour(DailyState s) {
    if (s.phase != DailyPhase.playing || _onboarding.hasSeenDailyTour) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _tourController.start();
    });
  }

  void _onTourStep() {
    if (_tourController.isActive) return;
    _onboarding.markDailyTourSeen();
  }

  List<SpotlightStep> _buildTourSteps() {
    final targets = {
      DailyTourStep.topBar: _headerKey,
      DailyTourStep.help: _helpKey,
      DailyTourStep.hint: _hintKey,
      DailyTourStep.mashqPill: _mashqPillKey,
      DailyTourStep.board: _boardKey,
    };
    const iconSteps = {DailyTourStep.help, DailyTourStep.hint};
    return DailyTourStep.values
        .map(
          (step) => SpotlightStep(
            targetKey: targets[step]!,
            title: step.titleKey.tr(),
            description: step == DailyTourStep.board
                ? step.bodyKey.tr(namedArgs: {'count': '${_cubit.maxAttempts}'})
                : step.bodyKey.tr(),
            shape: iconSteps.contains(step)
                ? SpotlightShape.circle
                : SpotlightShape.roundedRect,
          ),
        )
        .toList();
  }

  /// One-time board setup from the current state — the locked first letter, any
  /// restored guesses and the cursor. Called from initState (the BlocConsumer
  /// listener never fires for the *initial* state, and load() often emits
  /// synchronously during creation) and again from _sync, whichever lands first.
  void _restoreBoard(DailyState s) {
    if (_restored || s.phase == DailyPhase.loading) return;
    _board.setLockedPrefix(_cubit.lockedPrefix); // WS4
    for (var r = 0; r < s.guesses.length; r++) {
      _board.restoreRow(r, s.guesses[r]);
    }
    _rendered = s.guesses.length;
    _restored = true;
    if (s.phase == DailyPhase.playing) {
      // Locked first letter on the ACTIVE row only, cursor at tile 2.
      _board.setInput(
        _cubit.currentRow,
        _cubit.input.value,
        lockedPositions: _cubit.lockedPositions,
        prefillPositions: _cubit.prefillPositions,
      );
      _board.setCursor(_cubit.currentRow, _cubit.input.value.length);
    }
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
    if (!_checkedTour && s.phase != DailyPhase.loading) {
      _checkedTour = true;
      _maybeStartTour(s);
    }
    _restoreBoard(s);
    if (_restored && s.guesses.length > _rendered) {
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

    // A guess couldn't reach the backend (offline/5xx) — surface a toast
    // without shaking the row or clearing the staged input, so the player can
    // just press submit again.
    if (s.networkErrorSignal != _lastNetworkError) {
      _lastNetworkError = s.networkErrorSignal;
      AppHaptics.light();
      InvalidWordToast.show(context, message: LocaleKeys.dailyNetworkError.tr());
    }

    // Result interstitial (sj_result_inter): fired once when the daily resolves.
    if (!_resultAdShown &&
        (s.phase == DailyPhase.solved || s.phase == DailyPhase.failed)) {
      _resultAdShown = true;
      sl<RewardGateway>().showInterstitial(InterstitialPlacement.result);
    }

    // Win/loss choreography: only on a fresh transition from playing (never on a
    // restored, already-resolved board).
    final freshResolution = _prevPhase == DailyPhase.playing &&
        (s.phase == DailyPhase.solved || s.phase == DailyPhase.failed);
    if (_prevPhase == DailyPhase.playing && s.phase == DailyPhase.solved) {
      _runWinChoreography(s);
    } else if (_prevPhase == DailyPhase.playing &&
        s.phase == DailyPhase.failed) {
      AppHaptics.doubleTick();
    }
    if (freshResolution) _handleFirstResult();
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

  /// First-ever daily resolution (win or loss): count the solve and, per the
  /// pre-permission policy, surface the notification prompt card (WS2).
  Future<void> _handleFirstResult() async {
    await _notifPrompts.incrementSolveCount();
    if (!mounted) return;
    if (_notifPrompts.shouldPrompt) {
      setState(() => _showNotifPrompt = true);
    }
  }

  /// "Ha, eslat" — the ONLY path that triggers the OS permission prompt.
  Future<void> _acceptNotifPrompt() async {
    setState(() => _showNotifPrompt = false);
    await _notifPrompts.setStage(NotificationPromptStage.done);
    await sl<StreakReminderScheduler>().requestAndSchedule();
  }

  /// "Keyinroq" — postpone (re-ask after the 3rd solve), then never auto-ask.
  Future<void> _laterNotifPrompt() async {
    final next = NotificationPromptPolicy.afterPostpone(_notifPrompts.stage);
    setState(() => _showNotifPrompt = false);
    await _notifPrompts.setStage(next);
  }

  Widget? _notifBanner() => _showNotifPrompt
      ? NotificationPromptCard(
          onAccept: _acceptNotifPrompt,
          onLater: _laterNotifPrompt,
        )
      : null;

  /// "Yana yechish" bonus action (WS3): pro users start a bonus word; free users
  /// see it locked and tapping opens the shop's remove-ads hero (natural upsell).
  Widget _bonusButton() => BonusButton(
        isPro: sl<PurchasesRepository>().removeAds.value,
        onPlay: () => context.pushNamed(AppRoutes.bonusName),
        onUpsell: () => context.push(AppRoutes.shop),
      );

  /// Daily rollover: rebuild for the new puzzle date without an app restart.
  void _reloadForNewDay() {
    setState(() {
      _board.clear();
      _rendered = 0;
      _restored = false;
      _resultAdShown = false;
      _showNotifPrompt = false;
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
    _tourController.removeListener(_onTourStep);
    _tourController.dispose();
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
                    a.loadError != b.loadError ||
                    a.guesses.length != b.guesses.length ||
                    a.streak != b.streak ||
                    a.chestUnclaimed != b.chestUnclaimed ||
                    a.reward != b.reward,
                builder: (context, state) {
                  return Column(
                    children: [
                      const SizedBox(height: 8),
                      DailyHeader(
                        key: _headerKey,
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
          SpotlightTour(controller: _tourController, steps: _buildTourSteps()),
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
      remaining: _remaining,
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
      dictionaryAvailable: _cubit.hasDefinition,
      revealAdAvailable: reward.isReady(RewardedPlacement.hintLetter).value,
      cleanAdAvailable: reward.isReady(RewardedPlacement.hintClean).value,
      cleanAvailable: _cubit.canCleanKeyboard,
      // Reveal-letter/clean-keyboard need the plaintext answer, which the
      // client no longer holds during play now that evaluation is
      // server-authoritative — hidden until a dedicated hint endpoint exists
      // (practice is unaffected).
      showRevealCard: false,
      showCleanCard: false,
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

    // Clean-keyboard: the cubit charges (via pay) only when a letter is actually
    // grayed, and refunds coins on any failure so a charge never lands without a
    // visible effect (WS3 req b/c).
    if (type == HintType.cleanKeyboard) {
      return _cubit.purchaseCleanKeyboard(
        pay: pay,
        refund: viaAd
            ? () async {}
            : () => _wallet.creditCoins(price, reason: 'hint_clean_refund'),
      );
    }

    // Lugʻat: charge only after the themed definition dialog actually displays,
    // refunding on any failure (WS1 req c/d). No ad path for this hint.
    if (type == HintType.dictionary) {
      return _cubit.purchaseDefinition(
        pay: pay,
        refund: () =>
            _wallet.creditCoins(price, reason: 'hint_dictionary_refund'),
        reveal: _showDefinitionDialog,
      );
    }

    if (!await pay()) return false;
    if (type == HintType.revealLetter) _cubit.revealLetter();
    return true;
  }

  /// Atomic re-expand of the collapsed theme chip: coins when affordable,
  /// otherwise the existing rewarded-ad fallback surface — either way the
  /// charge lands only if the card actually re-shows ([show] succeeds).
  Future<bool> _reexpandTheme(Future<bool> Function() show) {
    final config = sl<GameConfig>();
    final reward = sl<RewardGateway>();
    final cost = config.hintThemeReexpandCost;
    final viaAd = _wallet.coins.value < cost;
    Future<bool> pay() => viaAd
        ? reward.showRewardedAd(RewardedPlacement.hintTheme)
        : _wallet.debitCoins(cost, reason: 'daily_theme_reexpand');
    return _cubit.purchaseThemeReexpand(
      pay: pay,
      refund: viaAd
          ? () async {}
          : () => _wallet.creditCoins(cost, reason: 'daily_theme_reexpand_refund'),
      show: show,
    );
  }

  Future<bool> _showDefinitionDialog(String definition) async {
    if (!mounted) return false;
    await showAppDialog<void>(
      context,
      child: DefinitionHintDialog(definition: definition),
    );
    return true;
  }

  Widget _body(DailyState state) {
    switch (state.phase) {
      case DailyPhase.loading:
        if (state.loadError) {
          return DailyLoadErrorView(onRetry: _reloadForNewDay);
        }
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
          banner: _notifBanner(),
          bonusAction: _bonusButton(),
        );
      case DailyPhase.failed:
        return FailView(
          guesses: state.guesses,
          answer: state.answer,
          definition: state.answerDefinition,
          remaining: _remaining,
          onShare: () => _openShare(state),
          onElapsed: _reloadForNewDay,
          banner: _notifBanner(),
          bonusAction: _bonusButton(),
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
          rulesButtonKey: _helpKey,
          hintButtonKey: _hintKey,
        ),
        if (state.theme != null) ...[
          const SizedBox(height: 8),
          PracticeThemeBanner(
            theme: state.theme,
            roundNonce: state.puzzleNumber,
            reexpandCost: sl<GameConfig>().hintThemeReexpandCost,
            initialSeconds: sl<GameConfig>().hintThemeInitialSeconds,
            reexpandSeconds: sl<GameConfig>().hintThemeReexpandSeconds,
            // One free auto-show per puzzle, persisted with the board snapshot
            // — a restored board (app restart) starts collapsed as the chip.
            autoShow: !_cubit.themeHintAlreadyShown,
            onAutoShown: _cubit.markThemeHintShown,
            onReexpand: _reexpandTheme,
          ),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: Align(
            alignment: Alignment.topCenter,
            child: ValueListenableBuilder<String>(
              valueListenable: _skins.activeSkinId,
              builder: (context, id, _) => TileSkinScope(
                skin: TileSkin.byId(id),
                child: GameBoard(
                  key: _boardKey,
                  controller: _board,
                  tileSize: _tileSize,
                  gap: _gap,
                ),
              ),
            ),
          ),
        ),
        MashqPill(
            key: _mashqPillKey, onTap: () => context.push(AppRoutes.practice)),
        const SizedBox(height: 12),
        GameKeyboard(
          keyStates: _keyStates,
          cleanPulse: _cubit.cleanPulse,
          onLetter: _onLetter,
          onEnter: _cubit.submit,
          onDelete: _cubit.removeLetter,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
