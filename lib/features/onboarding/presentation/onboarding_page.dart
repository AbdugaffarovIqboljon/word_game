import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/l10n/locale_keys.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/onboarding_repository.dart';

/// The welcome screen (screen_inventory §8). Its "Boshlash" CTA launches the
/// guided, playable tutorial (WS1); the color rules that used to be a static
/// step are now taught interactively inside that tutorial (and remain available
/// from the daily board's "Qoidalar" sheet).
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  void _start(BuildContext context) =>
      context.go(AppRoutes.tutorial, extra: true);

  Future<void> _skip(BuildContext context) async {
    await sl<OnboardingRepository>().markSeen();
    if (context.mounted) context.go(AppRoutes.daily);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 44,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: TextButton(
                    onPressed: () => _skip(context),
                    child: Text(
                      LocaleKeys.commonSkip.tr(),
                      style:
                          AppTextStyles.body.copyWith(color: AppColors.text3),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: _WelcomeStep(onStart: () => _start(context))),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.correct,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              'S',
              style: AppTextStyles.display.copyWith(color: AppColors.white),
            ),
          ),
          const SizedBox(height: 24),
          Text(LocaleKeys.appTitle.tr(), style: AppTextStyles.headline),
          const SizedBox(height: 12),
          Text(
            LocaleKeys.onboardingWelcomeTagline.tr(),
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 32),
          PrimaryButton(label: LocaleKeys.commonStart.tr(), onPressed: onStart),
        ],
      ),
    );
  }
}
