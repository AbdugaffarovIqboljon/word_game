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

/// Daily failed state (screen_inventory 1e): compact 42px 6-row board, the
/// answer + definition card, next-word countdown and a share button.
class FailView extends StatelessWidget {
  const FailView({
    required this.guesses,
    required this.answer,
    required this.definition,
    required this.remaining,
    required this.onShare,
    super.key,
  });

  final List<Guess> guesses;
  final List<LogicalLetter> answer;
  final String? definition;
  final Duration Function() remaining;
  final VoidCallback onShare;

  String get _answerWord => answer.map((l) => l.glyph).join();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          StaticBoard(guesses: guesses, columns: 5, tileSize: 42),
          const SizedBox(height: 20),
          AppCard(
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
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: NextWordBox(remaining: remaining, compact: true)),
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
        ],
      ),
    );
  }
}
