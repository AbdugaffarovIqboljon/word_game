import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/analytics/analytics_service.dart';
import 'core/analytics/firebase_analytics_service.dart';
import 'core/config/env.dart';
import 'core/config/remote_config_service.dart';
import 'core/di/service_locator.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/l10n/app_locales.dart';
import 'core/services/notification_service.dart';
import 'core/supabase/supabase_bootstrap.dart';
import 'features/ads/data/admob_reward_gateway.dart';
import 'features/ads/domain/reward_gateway.dart';
import 'features/shop/data/purchase_fulfiller.dart';
import 'features/shop/data/purchases_repository.dart';
import 'features/shop/data/store_iap_gateway.dart';
import 'features/shop/domain/purchase_gateway.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Firebase comes up defensively; when absent the app runs on no-op analytics
  // and local config defaults (see bootstrapFirebase / RemoteConfigService).
  final firebaseAvailable = await bootstrapFirebase();
  final AnalyticsService analytics = firebaseAvailable
      ? FirebaseAnalyticsService(FirebaseAnalytics.instance)
      : const NoopAnalyticsService();
  final configOverrides = await RemoteConfigService.fetchOverrides(
    firebaseAvailable: firebaseAvailable,
  );

  // Supabase comes up defensively too; when absent (no --dart-define in a
  // debug build) daily mode's puzzle repository fails fast with a retry-able
  // error instead of touching an uninitialized client.
  final supabaseAvailable = await bootstrapSupabase();

  await configureDependencies(
    analytics: analytics,
    configOverrides: configOverrides,
    supabaseClient: supabaseAvailable ? Supabase.instance.client : null,
  );

  // Release builds swap the fake reward gateway for real AdMob. Consent + SDK
  // init + preload happen inside create(); it never throws. Debug/tests keep the
  // fake (Env.useFakeAds defaults true in debug).
  if (!Env.useFakeAds) {
    final ads = await AdmobRewardGateway.create(
      prefs: sl(),
      config: sl(),
      analytics: sl(),
      removeAdsActive: () => sl<PurchasesRepository>().removeAds.value,
    );
    if (sl.isRegistered<RewardGateway>()) sl.unregister<RewardGateway>();
    sl.registerSingleton<RewardGateway>(ads);
  }

  // Release builds swap the fake purchase gateway for real store billing.
  if (!Env.useFakeIap) {
    final iap = await StoreIapGateway.create(fulfiller: sl<PurchaseFulfiller>());
    if (sl.isRegistered<PurchaseGateway>()) sl.unregister<PurchaseGateway>();
    sl.registerSingleton<PurchaseGateway>(iap);
  }

  // Local notifications (streak reminder). Permission is requested later, at
  // onboarding completion — not here.
  await sl<NotificationService>().init();

  analytics.sessionStart();

  runApp(
    EasyLocalization(
      supportedLocales: AppLocales.supported,
      path: AppLocales.path,
      startLocale: AppLocales.start,
      fallbackLocale: AppLocales.fallback,
      child: const SozJangiApp(),
    ),
  );
}
