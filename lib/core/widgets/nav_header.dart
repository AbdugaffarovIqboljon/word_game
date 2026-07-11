import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_text_styles.dart';
import 'app_icon_button.dart';

/// Standard pushed-screen header: back chevron, centered title, optional
/// trailing widget (nav-title role, screen_inventory §6/§7 back-chevron pattern).
class NavHeader extends StatelessWidget {
  const NavHeader({required this.title, this.trailing, this.onBack, super.key});

  final String title;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          AppIconButton(
            icon: AppIcons.back,
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.navTitle,
            ),
          ),
          trailing ?? const SizedBox(width: 34),
        ],
      ),
    );
  }
}
