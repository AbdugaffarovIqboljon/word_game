import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/bonus/presentation/bonus_play_page.dart';
import '../../features/daily/domain/daily_share_data.dart';
import '../../features/daily/presentation/daily_page.dart';
import '../../features/daily/presentation/share_page.dart';
import '../../features/onboarding/data/onboarding_repository.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../../features/onboarding/presentation/tutorial_page.dart';
import '../../features/practice/presentation/practice_hub_page.dart';
import '../../features/practice/presentation/practice_play_page.dart';
import '../../features/settings/presentation/attribution_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/shop/presentation/shop_page.dart';
import '../../features/stats/presentation/stats_page.dart';
import '../../features/streak/presentation/streak_page.dart';
import '../app_navigator.dart';
import '../config/game_config.dart';
import 'app_routes.dart';

/// Builds the app's [GoRouter]. No navigation shell (decisions §2) — every
/// destination is a flat route reached from the Daily header. `/daily/share`
/// and `/practice/play` are stacked sub-routes so they render over their parent.
GoRouter createRouter(OnboardingRepository onboarding) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.daily,
    redirect: (context, state) {
      final seenOnboarding = onboarding.hasSeenOnboarding;
      final loc = state.matchedLocation;
      // The welcome screen and the tutorial together make up the onboarding flow.
      final inOnboardingFlow =
          loc == AppRoutes.onboarding || loc == AppRoutes.tutorial;
      if (!seenOnboarding && !inOnboardingFlow) return AppRoutes.onboarding;
      if (seenOnboarding && loc == AppRoutes.onboarding) return AppRoutes.daily;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        name: AppRoutes.onboardingName,
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: AppRoutes.tutorial,
        name: AppRoutes.tutorialName,
        builder: (context, state) =>
            TutorialPage(fromOnboarding: state.extra as bool? ?? true),
      ),
      GoRoute(
        path: AppRoutes.daily,
        name: AppRoutes.dailyName,
        builder: (context, state) => const DailyPage(),
        routes: [
          GoRoute(
            path: AppRoutes.share,
            name: AppRoutes.shareName,
            pageBuilder: (context, state) => MaterialPage(
              fullscreenDialog: true,
              child: SharePage(data: state.extra as DailyShareData?),
            ),
          ),
          GoRoute(
            path: AppRoutes.bonus,
            name: AppRoutes.bonusName,
            builder: (context, state) => const BonusPlayPage(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.practice,
        name: AppRoutes.practiceName,
        builder: (context, state) => const PracticeHubPage(),
        routes: [
          GoRoute(
            path: AppRoutes.practicePlay,
            name: AppRoutes.practicePlayName,
            builder: (context, state) {
              final tier = state.extra as PracticeTier? ?? PracticeTier.easy;
              return PracticePlayPage(tier: tier);
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.stats,
        name: AppRoutes.statsName,
        builder: (context, state) => const StatsPage(),
      ),
      GoRoute(
        path: AppRoutes.shop,
        name: AppRoutes.shopName,
        builder: (context, state) => const ShopPage(),
      ),
      GoRoute(
        path: AppRoutes.streak,
        name: AppRoutes.streakName,
        builder: (context, state) => const StreakPage(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: AppRoutes.settingsName,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.attribution,
        name: AppRoutes.attributionName,
        builder: (context, state) => const AttributionPage(),
      ),
    ],
  );
}
