import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/game/domain/game_state.dart';
import '../../../core/game/domain/letter_result.dart';
import '../../../core/game/domain/logical_letter.dart';
import '../../../core/game/presentation/board_controller.dart';
import '../../../core/game/presentation/widgets/game_board.dart';
import '../../../core/game/presentation/widgets/game_keyboard.dart';
import '../../../core/l10n/locale_keys.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/services/app_haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/confetti_overlay.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/onboarding_repository.dart';
import '../domain/tutorial_script.dart';

/// The five scripted stages of the guided tutorial (WS1).
enum _Beat { typing, revealing, teaching, solving, won, lost }

/// A single, fully-playable scripted puzzle that teaches the color mechanic to a
/// first-time player who has never seen a word-guessing game.
///
/// Beat 1 — type the guided word OLTIN (only the next needed key is enabled) and
/// submit for a real flip. Beat 2 — sequential tap-to-advance callouts point at
/// a green / amber / gray tile. Beat 3 — the keyboard unlocks and the player
/// genuinely solves KITOB (or, on failure, the answer is gently revealed). Win
/// or loss both celebrate before returning to the app.
class TutorialPage extends StatefulWidget {
  const TutorialPage({this.fromOnboarding = true, super.key});

  /// True when reached from the welcome screen (finish → daily); false when
  /// relaunched from Settings (finish → pop back).
  final bool fromOnboarding;

  @override
  State<TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends State<TutorialPage> {
  static const double _tileSize = 48;
  static const double _gap = 6;
  static const Duration _revealDuration = Duration(milliseconds: 700);

  late final BoardController _board = BoardController(
    rows: TutorialScript.rows,
    columns: TutorialScript.columns,
  );
  final ValueNotifier<Map<LogicalLetter, LetterResult>> _keyStates =
      ValueNotifier(const {});
  final ValueNotifier<int> _confetti = ValueNotifier(0);

  late GameState _game = GameState.playing(
    answer: TutorialScript.answer,
    wordLength: TutorialScript.columns,
    maxAttempts: TutorialScript.rows,
  );
  _Beat _beat = _Beat.typing;
  int _teachStep = 0; // 0 → green, 1 → amber, 2 → gray

  @override
  void initState() {
    super.initState();
    _board.setCursor(0, 0);
  }

  @override
  void dispose() {
    _board.dispose();
    _keyStates.dispose();
    _confetti.dispose();
    super.dispose();
  }

  int get _row => _game.guesses.length;

  /// Beat 1 enables only OLTIN's next-needed letter; the flip locks the whole
  /// keyboard; Beat 3 unlocks everything.
  Set<LogicalLetter>? get _enabledLetters {
    switch (_beat) {
      case _Beat.typing:
        final i = _game.input.length;
        return i < TutorialScript.firstGuess.length
            ? {TutorialScript.firstGuess[i]}
            : const {};
      case _Beat.revealing:
        return const {};
      default:
        return null;
    }
  }

  void _addLetter(LogicalLetter letter) {
    if (_beat != _Beat.typing && _beat != _Beat.solving) return;
    final next = _game.addLetter(letter);
    if (identical(next, _game)) return;
    _game = next;
    _board.setInput(_row, _game.input);
    setState(() => _board.setCursor(_row, _game.input.length));
  }

  void _removeLetter() {
    final next = _game.removeLetter();
    if (identical(next, _game)) return;
    _game = next;
    _board.setInput(_row, _game.input);
    setState(() => _board.setCursor(_row, _game.input.length));
  }

  Future<void> _submit() async {
    if (_beat != _Beat.typing && _beat != _Beat.solving) return;
    if (_game.input.length < TutorialScript.columns) {
      _board.shakeRow(_row);
      AppHaptics.light();
      return;
    }
    final wasTyping = _beat == _Beat.typing;
    final row = _row;
    _game = _game.submit();
    _board.revealRow(row, _game.guesses.last);
    _keyStates.value = _game.keyboardStates;
    setState(() {
      _beat = _Beat.revealing;
      _board.setCursor(-1, -1);
    });

    await Future.delayed(_revealDuration);
    if (!mounted) return;

    if (wasTyping) {
      setState(() {
        _beat = _Beat.teaching;
        _teachStep = 0;
      });
    } else if (_game.status == GameStatus.won) {
      _celebrate(_Beat.won);
    } else if (_game.status == GameStatus.lost) {
      _celebrate(_Beat.lost);
    } else {
      setState(() {
        _beat = _Beat.solving;
        _board.setCursor(_row, 0);
      });
    }
  }

  void _advanceTeach() {
    if (_teachStep < 2) {
      setState(() => _teachStep++);
      return;
    }
    setState(() {
      _beat = _Beat.solving;
      _board.setCursor(_row, 0);
    });
  }

  void _celebrate(_Beat outcome) {
    _confetti.value++;
    AppHaptics.medium();
    setState(() => _beat = outcome);
  }

  Future<void> _finish({required bool completed}) async {
    final onboarding = sl<OnboardingRepository>();
    if (widget.fromOnboarding) await onboarding.markSeen();
    if (completed) await onboarding.markTutorialCompleted();
    if (!mounted) return;
    if (widget.fromOnboarding) {
      context.go(AppRoutes.daily);
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: _beat == _Beat.won || _beat == _Beat.lost
                        ? const SizedBox(height: 44)
                        : SizedBox(
                            height: 44,
                            child: TextButton(
                              onPressed: () => _finish(completed: false),
                              child: Text(
                                LocaleKeys.commonSkip.tr(),
                                style: AppTextStyles.body
                                    .copyWith(color: AppColors.text3),
                              ),
                            ),
                          ),
                  ),
                  Expanded(child: _beatBody()),
                ],
              ),
            ),
          ),
          ConfettiOverlay(trigger: _confetti),
        ],
      ),
    );
  }

  Widget _beatBody() {
    switch (_beat) {
      case _Beat.typing:
      case _Beat.revealing:
      case _Beat.solving:
        final coachText = _beat == _Beat.solving
            ? LocaleKeys.tutorialBeat3Coach.tr()
            : LocaleKeys.tutorialBeat1Coach.tr();
        return Column(
          children: [
            const SizedBox(height: 4),
            _CoachBubble(text: coachText, background: AppColors.surface2),
            Expanded(child: Center(child: _boardStack())),
            GameKeyboard(
              keyStates: _keyStates,
              enabledLetters: _enabledLetters,
              onLetter: _addLetter,
              onEnter: _submit,
              onDelete: _removeLetter,
            ),
            const SizedBox(height: 8),
          ],
        );
      case _Beat.teaching:
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _advanceTeach,
          child: Column(
            children: [
              const SizedBox(height: 4),
              _CoachBubble(
                text: _teachText,
                background: AppColors.surface2,
                swatch: _teachSwatch,
              ),
              Expanded(child: Center(child: _boardStack())),
              Text(
                LocaleKeys.tutorialTapToContinue.tr(),
                style: AppTextStyles.caption.copyWith(color: AppColors.textSub),
              ),
              const SizedBox(height: 28),
            ],
          ),
        );
      case _Beat.won:
      case _Beat.lost:
        return Column(
          children: [
            Expanded(child: Center(child: _boardStack())),
            _FinishPanel(
              won: _beat == _Beat.won,
              onFinish: () => _finish(completed: true),
            ),
            const SizedBox(height: 24),
          ],
        );
    }
  }

  Widget _boardStack() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GameBoard(controller: _board, tileSize: _tileSize, gap: _gap),
        if (_beat == _Beat.typing)
          Positioned(
            top: 0,
            left: 0,
            child: IgnorePointer(
              child: _GhostWord(
                letters: TutorialScript.firstGuess,
                typed: _game.input.length,
                tileSize: _tileSize,
                gap: _gap,
              ),
            ),
          ),
        if (_beat == _Beat.teaching)
          Positioned(
            top: 0,
            left: _teachIndex * (_tileSize + _gap),
            child: _TileSpotlight(size: _tileSize),
          ),
      ],
    );
  }

  int get _teachIndex => switch (_teachStep) {
    0 => TutorialScript.correctIndex,
    1 => TutorialScript.presentIndex,
    _ => TutorialScript.absentIndex,
  };

  String get _teachText => switch (_teachStep) {
    0 => LocaleKeys.tutorialTeachCorrect.tr(),
    1 => LocaleKeys.tutorialTeachPresent.tr(),
    _ => LocaleKeys.tutorialTeachAbsent.tr(),
  };

  Color get _teachSwatch => switch (_teachStep) {
    0 => AppColors.correct,
    1 => AppColors.present,
    _ => AppColors.tileAbsentBg,
  };
}

/// Rounded coach bubble; the optional [swatch] shows the color being explained.
class _CoachBubble extends StatelessWidget {
  const _CoachBubble({required this.text, required this.background, this.swatch});

  final String text;
  final Color background;
  final Color? swatch;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadii.cardR,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (swatch != null) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: swatch,
                borderRadius: AppRadii.tileR,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyStrong.copyWith(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

/// Faint OLTIN letters shown in the still-empty tiles of the first row.
class _GhostWord extends StatelessWidget {
  const _GhostWord({
    required this.letters,
    required this.typed,
    required this.tileSize,
    required this.gap,
  });

  final List<LogicalLetter> letters;
  final int typed;
  final double tileSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[];
    for (var i = 0; i < letters.length; i++) {
      if (i > 0) cells.add(SizedBox(width: gap));
      cells.add(
        SizedBox(
          width: tileSize,
          height: tileSize,
          child: i >= typed
              ? Center(
                  child: Opacity(
                    opacity: 0.28,
                    child: Text(
                      letters[i].glyph,
                      style: AppTextStyles.tile(
                        tileSize / 2,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                )
              : null,
        ),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: cells);
  }
}

/// Soft pulsing ring drawn over the tile a teach callout points at.
class _TileSpotlight extends StatefulWidget {
  const _TileSpotlight({required this.size});

  final double size;

  @override
  State<_TileSpotlight> createState() => _TileSpotlightState();
}

class _TileSpotlightState extends State<_TileSpotlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              borderRadius: AppRadii.tileR,
              border: Border.all(
                color: Color.lerp(
                  AppColors.white,
                  AppColors.tileCursorBorder,
                  _pulse.value,
                )!,
                width: 3,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Win / loss finish panel: celebratory copy (or a gentle reveal) and the CTA
/// that returns to the app.
class _FinishPanel extends StatelessWidget {
  const _FinishPanel({required this.won, required this.onFinish});

  final bool won;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          won
              ? LocaleKeys.tutorialWinTitle.tr()
              : LocaleKeys.tutorialLoseTitle.tr(),
          textAlign: TextAlign.center,
          style: AppTextStyles.title,
        ),
        const SizedBox(height: 8),
        Text(
          won
              ? LocaleKeys.tutorialWinBody.tr()
              : LocaleKeys.tutorialLoseBody.tr(),
          textAlign: TextAlign.center,
          style: AppTextStyles.body.copyWith(color: AppColors.text2),
        ),
        if (!won) ...[
          const SizedBox(height: 10),
          Text(
            TutorialScript.answerWord,
            textAlign: TextAlign.center,
            style: AppTextStyles.title.copyWith(
              letterSpacing: 4,
              color: AppColors.successBright,
            ),
          ),
        ],
        const SizedBox(height: 20),
        PrimaryButton(
          label: LocaleKeys.tutorialFinishCta.tr(),
          onPressed: onFinish,
        ),
      ],
    );
  }
}
