import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/game/domain/guess.dart';
import '../../../core/game/domain/letter_result.dart';
import '../../../core/game/domain/logical_letter.dart';
import '../../../core/game/presentation/tile_state.dart';
import '../../../core/game/presentation/widgets/game_keyboard.dart';
import '../../../core/game/presentation/widgets/static_board.dart';
import '../../../core/game/presentation/widgets/static_tile.dart';
import '../../../core/l10n/locale_keys.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/onboarding_repository.dart';

/// One-time onboarding (screen_inventory §8): welcome, color rules, and an
/// interactive "try it" step that advances on the first key tap (decisions §8).
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _step = 0;
  final ValueNotifier<Map<LogicalLetter, LetterResult>> _demoKeys =
      ValueNotifier(const {});

  Future<void> _finish() async {
    await sl<OnboardingRepository>().markSeen();
    if (mounted) context.go(AppRoutes.daily);
  }

  void _next() => setState(() => _step++);

  @override
  void dispose() {
    _demoKeys.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: _step < 2
                  ? Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: TextButton(
                          onPressed: _finish,
                          child: Text(
                            LocaleKeys.commonSkip.tr(),
                            style: AppTextStyles.body.copyWith(color: AppColors.text3),
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
            Expanded(
              child: switch (_step) {
                0 => _WelcomeStep(onStart: _next),
                1 => _RulesStep(onContinue: _next),
                _ => _TryStep(demoKeys: _demoKeys, onFirstTap: _finish),
              },
            ),
            _DotIndicator(step: _step),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.correct,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text('S', style: AppTextStyles.display.copyWith(color: AppColors.white)),
          ),
          const SizedBox(height: 24),
          Text(LocaleKeys.appTitle.tr(), style: AppTextStyles.headline),
          const SizedBox(height: 12),
          Text(
            LocaleKeys.onboardingWelcomeTagline.tr(),
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 32),
          PrimaryButton(label: LocaleKeys.commonStart.tr(), onPressed: onStart),
        ],
      ),
    );
  }
}

class _RulesStep extends StatelessWidget {
  const _RulesStep({required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(LocaleKeys.onboardingRulesTitle.tr(), style: AppTextStyles.title, textAlign: TextAlign.center),
          const SizedBox(height: 28),
          _RuleRow(letter: 'a', state: TileState.correct, text: LocaleKeys.onboardingRuleCorrect.tr()),
          const SizedBox(height: 16),
          _RuleRow(letter: 'l', state: TileState.present, text: LocaleKeys.onboardingRulePresent.tr()),
          const SizedBox(height: 16),
          _RuleRow(letter: 'k', state: TileState.absent, text: LocaleKeys.onboardingRuleAbsent.tr()),
          const SizedBox(height: 32),
          PrimaryButton(label: LocaleKeys.commonContinue.tr(), onPressed: onContinue),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({required this.letter, required this.state, required this.text});
  final String letter;
  final TileState state;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StaticTile(data: TileData(letter: letter, state: state), size: 56),
        const SizedBox(width: 16),
        Expanded(child: Text(text, style: AppTextStyles.body.copyWith(color: AppColors.text))),
      ],
    );
  }
}

class _TryStep extends StatelessWidget {
  const _TryStep({required this.demoKeys, required this.onFirstTap});

  final ValueListenable<Map<LogicalLetter, LetterResult>> demoKeys;
  final VoidCallback onFirstTap;

  static final _demoGuess = Guess(
    letters: [
      const LogicalLetter('s'),
      const LogicalLetter('a'),
      const LogicalLetter('l'),
      const LogicalLetter('o'),
      const LogicalLetter('m'),
    ],
    results: const [
      LetterResult.absent,
      LetterResult.correct,
      LetterResult.present,
      LetterResult.absent,
      LetterResult.correct,
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Text(LocaleKeys.onboardingTryTitle.tr(), style: AppTextStyles.title, textAlign: TextAlign.center),
        Expanded(
          child: Center(
            child: StaticBoard(
              guesses: [_demoGuess],
              columns: 5,
              rows: 3,
              tileSize: 52,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.correct,
            borderRadius: AppRadii.pillR,
          ),
          child: Text(
            LocaleKeys.onboardingTryCoachmark.tr(),
            style: AppTextStyles.bodyStrong.copyWith(fontSize: 14, color: AppColors.white),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GameKeyboard(
            keyStates: demoKeys,
            onLetter: (_) => onFirstTap(),
            onEnter: onFirstTap,
            onDelete: onFirstTap,
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _DotIndicator extends StatelessWidget {
  const _DotIndicator({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == step ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == step ? AppColors.correct : AppColors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
