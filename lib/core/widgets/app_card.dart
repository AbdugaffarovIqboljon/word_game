import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';

/// Generic content card: surface fill, hairline border, radius 16 (ALL cards are
/// 16 — decisions §3). Optional [onTap] makes it tappable.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.surface,
    this.borderColor = AppColors.border,
    this.onTap,
    this.shadow = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final VoidCallback? onTap;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: color,
      borderRadius: AppRadii.cardR,
      border: Border.all(color: borderColor),
      boxShadow: shadow ? AppShadows.card : null,
    );

    if (onTap == null) {
      return DecoratedBox(
        decoration: decoration,
        child: Padding(padding: padding, child: child),
      );
    }

    return Material(
      color: color,
      borderRadius: AppRadii.cardR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.cardR,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadii.cardR,
            border: Border.all(color: borderColor),
          ),
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}
