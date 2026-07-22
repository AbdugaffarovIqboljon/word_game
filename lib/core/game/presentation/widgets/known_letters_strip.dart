import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../l10n/locale_keys.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_radii.dart';
import '../../../theme/app_text_styles.dart';
import '../../domain/letter_result.dart';
import '../../domain/logical_letter.dart';
import '../../domain/uzbek_alphabet.dart';

/// Compact "known letters" strip shown directly above the board (WS2).
///
/// Amber (`present`) letters are never pre-filled into board tiles anymore —
/// they surface here instead: a "Soʻzda bor:" label followed by deduped amber
/// chips in alphabet order. It listens to the same [keyStates] the keyboard
/// does, so a letter leaves the strip the moment it is confirmed green
/// (`present` → `correct` upgrade). The whole row collapses to nothing while no
/// unplaced amber letters exist.
class KnownLettersStrip extends StatelessWidget {
  const KnownLettersStrip({required this.keyStates, super.key});

  final ValueListenable<Map<LogicalLetter, LetterResult>> keyStates;

  /// Alphabet index for stable ordering (keyboard order == Uzbek Latin order).
  static int _order(LogicalLetter l) => UzbekAlphabet.letters.indexOf(l);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<LogicalLetter, LetterResult>>(
      valueListenable: keyStates,
      builder: (context, states, _) {
        final present =
            states.entries
                .where((e) => e.value == LetterResult.present)
                .map((e) => e.key)
                .toList()
              ..sort((a, b) => _order(a).compareTo(_order(b)));
        if (present.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                LocaleKeys.gameKnownLettersLabel.tr(),
                style: AppTextStyles.caption.copyWith(color: AppColors.textSub),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final letter in present) _LetterChip(letter: letter),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LetterChip extends StatelessWidget {
  const _LetterChip({required this.letter});

  final LogicalLetter letter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.present,
        borderRadius: AppRadii.tileR,
      ),
      child: Text(
        letter.glyph,
        style: AppTextStyles.tile(13, color: AppColors.onPresent),
      ),
    );
  }
}
