import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/game/domain/guess.dart';
import '../../../../core/game/domain/logical_letter.dart';
import '../../../../core/game/presentation/widgets/static_board.dart';
import '../../../../core/l10n/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/primary_button.dart';
import 'next_word_box.dart';

/// Daily failed state (screen_inventory 1e): compact 42px board (5 rows after the
/// WS4 attempts reduction), the answer + definition card, next-word countdown and
/// a share button.
class FailView extends StatelessWidget {
  const FailView({
    required this.guesses,
    required this.answer,
    required this.definition,
    required this.remaining,
    required this.onShare,
    this.onElapsed,
    this.banner,
    this.bonusAction,
    super.key,
  });

  final List<Guess> guesses;
  final List<LogicalLetter> answer;
  final String? definition;
  final Duration Function() remaining;
  final VoidCallback onShare;
  final VoidCallback? onElapsed;

  /// Optional card rendered above the fail layout (notification prompt, WS2).
  final Widget? banner;

  /// Optional "Yana yechish" bonus action (WS3), rendered below the share row.
  final Widget? bonusAction;

  String get _answerWord => answer.map((l) => l.glyph).join();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          if (banner != null) ...[
            banner!,
            const SizedBox(height: 20),
          ],
          StaticBoard(guesses: guesses, columns: 5, tileSize: 42),
          const SizedBox(height: 20),
          _FadeIn(
            child: AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  LocaleKeys.dailyFailedLabel.tr(),
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(color: AppColors.danger),
                ),
                const SizedBox(height: 10),
                Text(
                  _answerWord,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title.copyWith(letterSpacing: 4),
                ),
                if (definition != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    definition!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSub,
                    ),
                  ),
                ],
              ],
            ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: NextWordBox(
                  remaining: remaining,
                  compact: true,
                  onElapsed: onElapsed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: LocaleKeys.dailyShareResult.tr(),
                  variant: PrimaryButtonVariant.telegram,
                  icon: AppIcons.share,
                  height: 56,
                  onPressed: onShare,
                ),
              ),
            ],
          ),
          if (bonusAction != null) ...[
            const SizedBox(height: 16),
            bonusAction!,
          ],
        ],
      ),
    );
  }
}

/// Gentle fade + rise so the "you lost" answer card settles in instead of
/// snapping (audit DB-17).
class _FadeIn extends StatefulWidget {
  const _FadeIn({required this.child});

  final Widget child;

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _c,
    curve: Curves.easeOut,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(_fade),
        child: widget.child,
      ),
    );
  }
}
