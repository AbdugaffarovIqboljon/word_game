import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/game/presentation/tile_state.dart';
import '../../../../core/game/presentation/widgets/static_tile.dart';
import '../../../../core/l10n/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_text_styles.dart';

/// The color-rules legend (onboarding step 2). Extracted so the same content
/// backs both onboarding and the daily board's re-openable "Qoidalar" sheet.
class RulesLegend extends StatelessWidget {
  const RulesLegend({this.tileSize = 56, this.gap = 16, super.key});

  final double tileSize;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RuleRow(
          letter: 'a',
          state: TileState.correct,
          text: LocaleKeys.onboardingRuleCorrect.tr(),
          tileSize: tileSize,
        ),
        SizedBox(height: gap),
        _RuleRow(
          letter: 'l',
          state: TileState.present,
          text: LocaleKeys.onboardingRulePresent.tr(),
          tileSize: tileSize,
        ),
        SizedBox(height: gap),
        _RuleRow(
          letter: 'k',
          state: TileState.absent,
          text: LocaleKeys.onboardingRuleAbsent.tr(),
          tileSize: tileSize,
        ),
      ],
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.letter,
    required this.state,
    required this.text,
    required this.tileSize,
  });

  final String letter;
  final TileState state;
  final String text;
  final double tileSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        StaticTile(data: TileData(letter: letter, state: state), size: tileSize),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.body.copyWith(color: AppColors.text),
          ),
        ),
      ],
    );
  }
}

/// Opens the compact "Qoidalar" bottom sheet (daily board rules re-access).
Future<void> showRulesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.scrim,
    builder: (_) => const _RulesSheet(),
  );
}

class _RulesSheet extends StatelessWidget {
  const _RulesSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceModal,
        borderRadius: AppRadii.sheetTopR,
        border: Border(top: BorderSide(color: AppColors.border)),
        boxShadow: AppShadows.sheetUp,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(LocaleKeys.commonRules.tr(), style: AppTextStyles.sectionTitle),
              const SizedBox(height: 4),
              Text(
                LocaleKeys.onboardingWelcomeTagline.tr(),
                style: AppTextStyles.caption.copyWith(color: AppColors.textSub),
              ),
              const SizedBox(height: 20),
              const RulesLegend(tileSize: 48, gap: 14),
            ],
          ),
        ),
      ),
    );
  }
}
