import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_text_styles.dart';

enum PrimaryButtonVariant { green, telegram, premium, danger }

/// Full-width primary CTA (component_spec (c)). Raised colored-glow treatment
/// via [AppShadows.ctaGlow] plus a 1px top highlight approximating the spec's
/// inset sheen (Flutter has no inset shadow — decisions §5).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.variant = PrimaryButtonVariant.green,
    this.height = 54,
    this.icon,
    this.horizontalPadding = 0,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final PrimaryButtonVariant variant;
  final double height;
  final IconData? icon;

  /// Extra inline padding around the label/icon row. Full-width usages (the
  /// common case) don't need it — the button already stretches to fill a
  /// bounded-width parent regardless. Only compact usages placed in a `Row`
  /// (shop hero/starter-pack CTAs) need real breathing room around the text.
  final double horizontalPadding;

  Color get _brand => switch (variant) {
        PrimaryButtonVariant.green => AppColors.correct,
        PrimaryButtonVariant.telegram => AppColors.telegram,
        PrimaryButtonVariant.premium => AppColors.coin,
        PrimaryButtonVariant.danger => AppColors.danger,
      };

  /// Foreground on [_brand]. The gold `premium` brand is too light for white
  /// text/icons, so it pairs with `onGold` — the same gold/foreground contrast
  /// pair the shop's "best offer" badge already uses.
  Color get _onBrand => switch (variant) {
        PrimaryButtonVariant.premium => AppColors.onGold,
        PrimaryButtonVariant.green ||
        PrimaryButtonVariant.telegram ||
        PrimaryButtonVariant.danger =>
          AppColors.white,
      };

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadii.buttonR,
        boxShadow: enabled ? AppShadows.ctaGlow(_brand) : null,
      ),
      child: Material(
        color: enabled ? _brand : AppColors.disabledBg,
        borderRadius: AppRadii.buttonR,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadii.buttonR,
          child: Container(
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: AppRadii.buttonR,
              border: enabled
                  ? const Border(
                      top: BorderSide(color: Color(0x3AFFFFFF), width: 1),
                    )
                  : Border.all(color: AppColors.disabledBorder),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: 18,
                      color: enabled ? _onBrand : AppColors.disabledFg,
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Ellipsis-clamped so a long label under a large text scale
                  // shrinks within a constrained (e.g. half-width, in a Row)
                  // button instead of overflowing it (WS2).
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyStrong.copyWith(
                        fontSize: 16,
                        color: enabled ? _onBrand : AppColors.disabledFg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
