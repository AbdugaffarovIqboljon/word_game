import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/di/service_locator.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/onboarding/data/onboarding_repository.dart';

/// Root widget. Owns the [GoRouter] (created once, from DI) and applies the
/// single dark theme. easy_localization wraps this widget in `main`.
class SozJangiApp extends StatefulWidget {
  const SozJangiApp({super.key});

  @override
  State<SozJangiApp> createState() => _SozJangiAppState();
}

class _SozJangiAppState extends State<SozJangiApp> {
  late final GoRouter _router = createRouter(sl<OnboardingRepository>());

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: "So'z Jangi",
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: _router,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}
