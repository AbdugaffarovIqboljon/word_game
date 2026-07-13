import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../core/l10n/locale_keys.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';

/// Themed Lugʻat-hint dialog (WS1 req d): shows the answer's definition WITHOUT
/// revealing the word itself. Rendered inside [AppDialogCard] via [showAppDialog].
class DefinitionHintDialog extends StatelessWidget {
  const DefinitionHintDialog({required this.definition, super.key});

  final String definition;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                AppIcons.dictionary,
                size: 20,
                color: AppColors.successBright,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                LocaleKeys.hintDefinitionTitle.tr(),
                style: AppTextStyles.sectionTitle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          definition,
          style: AppTextStyles.body.copyWith(color: AppColors.text, height: 1.4),
        ),
        const SizedBox(height: 22),
        PrimaryButton(
          label: LocaleKeys.commonClose.tr(),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
