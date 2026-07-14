import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../analytics/analytics_service.dart';
import '../services/notification_service.dart';
import '../../features/notifications/data/notification_prompt_repository.dart';
import '../../features/streak/data/streak_reminder_scheduler.dart';
import '../../features/wallet/data/analytics_wallet_bridge.dart';
import '../../features/bonus/data/bonus_played_repository.dart';
import '../../features/daily/data/daily_board_repository.dart';
import '../../features/daily/data/daily_chest_repository.dart';
import '../../features/daily/data/supabase_daily_puzzle_repository.dart';
import '../../features/daily/domain/daily_puzzle_repository.dart';
import '../../features/daily/presentation/daily_cubit.dart';
import '../../features/onboarding/data/onboarding_repository.dart';
import '../../features/practice/data/practice_repository.dart';
import '../../features/settings/data/settings_service.dart';
import '../../features/shop/data/debug_purchase_gateway.dart';
import '../../features/shop/data/purchase_fulfiller.dart';
import '../../features/shop/data/purchases_repository.dart';
import '../../features/shop/data/skin_service.dart';
import '../../features/shop/domain/purchase_gateway.dart';
import '../../features/stats/data/stats_repository.dart';
import '../../features/streak/data/streak_history_repository.dart';
import '../../features/streak/data/streak_repository.dart';
import '../../features/wallet/data/wallet_service.dart';
import '../../features/wallet/domain/wallet_analytics.dart';
import '../../data/dictionary_datasource.dart';
import '../../features/ads/data/debug_reward_gateway.dart';
import '../../features/ads/domain/reward_gateway.dart';
import '../config/env.dart';
import '../config/game_config.dart';
import '../game/domain/dictionary.dart';
import '../storage/preferences_service.dart';
import '../time/game_clock.dart';

/// Global service locator.
final GetIt sl = GetIt.instance;

/// Registers every app-wide singleton. Called once at startup after the
/// platform [PreferencesService] has been loaded. Feature registrations are
/// grouped for readability.
Future<void> configureDependencies({
  AnalyticsService analytics = const NoopAnalyticsService(),
  Map<String, Object> configOverrides = const {},
  SupabaseClient? supabaseClient,
}) async {
  // ── Core ──────────────────────────────────────────────────────────────────
  final prefs = await PreferencesService.create();
  sl
    ..registerSingleton<PreferencesService>(prefs)
    ..registerSingleton<AnalyticsService>(analytics)
    ..registerSingleton<GameConfig>(GameConfig(overrides: configOverrides))
    ..registerLazySingleton<GameClock>(() => GameClock(config: sl()));

  // ── Game engine ───────────────────────────────────────────────────────────
  // Production dictionary: real bundled word assets + Supabase daily schedule
  // (offline-capable). Loaded async and awaited below so the synchronous
  // Dictionary interface is fully resident before first use. The in-memory fake
  // remains for unit tests only.
  sl
    ..registerSingletonAsync<SupabaseAssetDictionary>(
      () => SupabaseAssetDictionary.create(
        supabaseUrl: Env.supabaseUrl,
        supabaseAnonKey: Env.supabaseAnonKey,
      ),
    )
    ..registerLazySingleton<Dictionary>(() => sl<SupabaseAssetDictionary>());

  // ── Wallet (shared economy) ──────────────────────────────────────────────
  sl
    ..registerLazySingleton<WalletAnalytics>(
      () => AnalyticsWalletBridge(sl<AnalyticsService>()),
    )
    ..registerSingleton<WalletService>(
      WalletService(prefs: prefs, analytics: sl())..load(),
    );

  // ── Ads & purchases (debug fakes until real SDKs land) ───────────────────
  sl
    ..registerLazySingleton<RewardGateway>(() => const DebugRewardGateway())
    ..registerLazySingleton<PurchaseFulfiller>(
      () => PurchaseFulfiller(
        wallet: sl(),
        purchases: sl(),
        config: sl(),
        analytics: sl(),
      ),
    )
    ..registerLazySingleton<PurchaseGateway>(
      () => DebugPurchaseGateway(sl<PurchaseFulfiller>()),
    );

  // ── Settings ──────────────────────────────────────────────────────────────
  sl.registerSingleton<SettingsService>(SettingsService(prefs)..load());

  // ── Notifications (local daily streak reminder) ──────────────────────────
  sl
    ..registerLazySingleton<NotificationService>(() => NotificationService())
    ..registerLazySingleton<NotificationPromptRepository>(
      () => NotificationPromptRepository(sl()),
    )
    ..registerLazySingleton<StreakReminderScheduler>(
      () => StreakReminderScheduler(
        notifications: sl(),
        settings: sl(),
        streakRepo: sl(),
      ),
    );

  // ── Shop (skins + entitlements) ──────────────────────────────────────────
  sl
    ..registerSingleton<SkinService>(SkinService(prefs)..load())
    ..registerSingleton<PurchasesRepository>(PurchasesRepository(prefs)..load());

  // ── Onboarding ────────────────────────────────────────────────────────────
  sl.registerLazySingleton<OnboardingRepository>(
    () => OnboardingRepository(sl()),
  );

  // ── Practice ──────────────────────────────────────────────────────────────
  sl.registerLazySingleton<PracticeRepository>(() => PracticeRepository(sl()));

  // ── Daily / streak / stats ────────────────────────────────────────────────
  // Guess evaluation and puzzle metadata are server-authoritative (see
  // SupabaseDailyPuzzleRepository) — the repository fails fast with
  // DailyPuzzleUnavailableException when supabaseClient is null (Supabase
  // never initialized), which the cubit surfaces as a retry-able error.
  sl
    ..registerLazySingleton<DailyPuzzleRepository>(
      () => SupabaseDailyPuzzleRepository(supabaseClient),
    )
    ..registerLazySingleton<DailyBoardRepository>(() => DailyBoardRepository(sl()))
    ..registerLazySingleton<DailyChestRepository>(() => DailyChestRepository(sl()))
    ..registerLazySingleton<StreakRepository>(() => StreakRepository(sl()))
    ..registerLazySingleton<StreakHistoryRepository>(
      () => StreakHistoryRepository(sl()),
    )
    ..registerLazySingleton<StatsRepository>(() => StatsRepository(sl()))
    ..registerLazySingleton<BonusPlayedRepository>(
      () => BonusPlayedRepository(sl()),
    )
    ..registerFactory<DailyCubit>(
      () => DailyCubit(
        dictionary: sl(),
        puzzleRepo: sl(),
        clock: sl(),
        config: sl(),
        boardRepo: sl(),
        chestRepo: sl(),
        streakRepo: sl(),
        historyRepo: sl(),
        statsRepo: sl(),
        wallet: sl(),
      ),
    );

  // Wait for async singletons (the dictionary) to finish loading their assets.
  await sl.allReady();
}
