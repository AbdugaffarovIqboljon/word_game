import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';

/// Shows a centered modal using the app's dialog treatment (surface-modal fill,
/// 22px radius, dimmed scrim). [barrierDismissible] false for anti-accidental
/// flows (e.g. the rewarded-ad offer).
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required Widget child,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: AppColors.scrim,
    builder: (_) => AppDialogCard(child: child),
  );
}

/// The dialog card (component_spec (c) dialogs): surface-modal, 22px radius.
class AppDialogCard extends StatelessWidget {
  const AppDialogCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
        decoration: BoxDecoration(
          color: AppColors.surfaceModal,
          borderRadius: AppRadii.dialogR,
          border: Border.all(color: AppColors.border),
          boxShadow: AppShadows.modal,
        ),
        child: child,
      ),
    );
  }
}
