import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_icons.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';

/// Base pill counter (coin/gem): surface-2 fill, hairline border, radius 20,
/// icon + value (component_spec (c)).
class CounterChip extends StatelessWidget {
  const CounterChip({
    required this.icon,
    required this.iconColor,
    required this.value,
    this.onTap,
    this.valueColor = AppColors.text,
    this.borderColor = AppColors.border,
    this.fontSize = 13,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final VoidCallback? onTap;
  final Color valueColor;
  final Color borderColor;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: AppRadii.pillR,
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 6),
          Text(
            value,
            style: AppTextStyles.bodyStrong.copyWith(
              fontSize: fontSize,
              color: valueColor,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadii.pillR,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.pillR,
        child: content,
      ),
    );
  }
}

/// Coin chip bound to a live balance. Animates a 600ms count-up on change
/// (design motion "coin reward"). Tap → shop.
class CoinChip extends StatelessWidget {
  const CoinChip({required this.balance, this.onTap, super.key});

  final ValueListenable<int> balance;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: balance,
      builder: (context, value, _) => TweenAnimationBuilder<int>(
        // begin is only used on first build; later balance changes animate from
        // the previous value automatically (600ms count-up on reward).
        tween: IntTween(begin: 0, end: value),
        duration: const Duration(milliseconds: 600),
        builder: (context, shown, _) => CounterChip(
          icon: AppIcons.coins,
          iconColor: AppColors.coin,
          value: _format(shown),
          onTap: onTap,
        ),
      ),
    );
  }
}

/// Gem chip bound to a live balance. Tap → shop.
class GemChip extends StatelessWidget {
  const GemChip({required this.balance, this.onTap, super.key});

  final ValueListenable<int> balance;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: balance,
      builder: (context, value, _) => CounterChip(
        icon: AppIcons.gem,
        iconColor: AppColors.gem,
        value: _format(value),
        onTap: onTap,
      ),
    );
  }
}

/// Thin-space grouping for large numbers ("1 280").
String _format(int value) {
  final s = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(s[i]);
  }
  return buffer.toString();
}
