import 'package:flutter/foundation.dart';

/// Build-time environment configuration, supplied via `--dart-define`.
///
/// This is the single place every external ID is read. All of them have safe
/// defaults — Supabase is optional (the app runs fully offline off its bundled
/// assets) and every AdMob id defaults to Google's official **test** unit, so a
/// debug build compiles and runs with **zero real IDs provided**. Release CI
/// supplies the real values:
///
///   --dart-define=SUPABASE_URL=…  --dart-define=SUPABASE_ANON_KEY=…
///   --dart-define=USE_FAKE_ADS=false --dart-define=USE_FAKE_IAP=false
///   --dart-define=ADMOB_APP_ID_ANDROID=…  --dart-define=ADMOB_APP_ID_IOS=…
///   --dart-define=ADMOB_REWARDED_HINT_LETTER=…  (etc — see the switches below)
abstract final class Env {
  const Env._();

  // ── Supabase (optional; offline-first) ───────────────────────────────────
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  // ── Gateway selection ────────────────────────────────────────────────────
  /// Debug defaults to the fake gateways so nothing needs real IDs; release
  /// builds flip these off to activate AdMob / store billing.
  static const bool useFakeAds =
      bool.fromEnvironment('USE_FAKE_ADS', defaultValue: kDebugMode);
  static const bool useFakeIap =
      bool.fromEnvironment('USE_FAKE_IAP', defaultValue: kDebugMode);

  // ── AdMob application ids (SDK reads these from the manifest/plist; kept
  //    here so Phase F build config and docs share one source) ──────────────
  static const String admobAppIdAndroid = String.fromEnvironment(
    'ADMOB_APP_ID_ANDROID',
    defaultValue: 'ca-app-pub-3940256099942544~3347511713', // Google test app
  );
  static const String admobAppIdIos = String.fromEnvironment(
    'ADMOB_APP_ID_IOS',
    defaultValue: 'ca-app-pub-3940256099942544~1458002511', // Google test app
  );

  // ── Per-placement unit ids (empty → fall back to the platform test unit) ──
  static const String _rewardedHintLetter =
      String.fromEnvironment('ADMOB_REWARDED_HINT_LETTER');
  static const String _rewardedHintClean =
      String.fromEnvironment('ADMOB_REWARDED_HINT_CLEAN');
  static const String _rewardedChestDouble =
      String.fromEnvironment('ADMOB_REWARDED_CHEST_DOUBLE');
  static const String _rewardedFreezeFree =
      String.fromEnvironment('ADMOB_REWARDED_FREEZE_FREE');
  static const String _interPractice =
      String.fromEnvironment('ADMOB_INTERSTITIAL_PRACTICE');
  static const String _interResult =
      String.fromEnvironment('ADMOB_INTERSTITIAL_RESULT');

  /// Resolves a rewarded placement id (`sj_hint_letter` …) to its unit id,
  /// falling back to Google's platform-specific test rewarded unit.
  static String rewardedUnitId(String placementId) {
    final id = switch (placementId) {
      'sj_hint_letter' => _rewardedHintLetter,
      'sj_hint_clean' => _rewardedHintClean,
      'sj_chest_double' => _rewardedChestDouble,
      'sj_freeze_free' => _rewardedFreezeFree,
      _ => '',
    };
    return id.isNotEmpty ? id : _testRewardedUnitId;
  }

  /// Resolves an interstitial placement id (`sj_practice_inter` …) to its unit
  /// id, falling back to Google's platform-specific test interstitial unit.
  static String interstitialUnitId(String placementId) {
    final id = switch (placementId) {
      'sj_practice_inter' => _interPractice,
      'sj_result_inter' => _interResult,
      _ => '',
    };
    return id.isNotEmpty ? id : _testInterstitialUnitId;
  }

  static String get _testRewardedUnitId =>
      defaultTargetPlatform == TargetPlatform.iOS
          ? 'ca-app-pub-3940256099942544/1712485313'
          : 'ca-app-pub-3940256099942544/5224354917';

  static String get _testInterstitialUnitId =>
      defaultTargetPlatform == TargetPlatform.iOS
          ? 'ca-app-pub-3940256099942544/4411468910'
          : 'ca-app-pub-3940256099942544/1033173712';
}
