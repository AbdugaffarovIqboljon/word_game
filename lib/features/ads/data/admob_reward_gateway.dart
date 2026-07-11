import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../core/config/env.dart';
import '../../../core/config/game_config.dart';
import '../../../core/storage/preferences_service.dart';
import '../domain/reward_gateway.dart';

/// Production [RewardGateway] over Google Mobile Ads.
///
/// Behaviour:
///  * UMP consent is resolved before any ad load (required by AdMob).
///  * Every rewarded placement is preloaded on launch and reloaded after each
///    show; [isReady] flips false on no-fill so the UI hides the offer button.
///  * Reward is granted strictly on `onUserEarnedReward`.
///  * Interstitials obey the frequency rules from [GameConfig]/RemoteConfig:
///    session warm-up, minimum gap, daily cap, a per-day cap for the result
///    placement, never immediately after a rewarded ad, and never at all once
///    remove-ads is owned.
///  * Every impression and grant fires the analytics taxonomy.
///
/// Construct via [create], which performs consent + SDK init + preload and never
/// throws — on any failure it returns a gateway that simply reports nothing
/// ready (all ad buttons hide) rather than crashing launch.
class AdmobRewardGateway implements RewardGateway {
  AdmobRewardGateway({
    required PreferencesService prefs,
    required GameConfig config,
    required AnalyticsService analytics,
    required bool Function() removeAdsActive,
    DateTime Function()? now,
  })  : _prefs = prefs,
        _config = config,
        _analytics = analytics,
        _removeAdsActive = removeAdsActive,
        _now = now ?? DateTime.now {
    _sessionStart = _now();
  }

  final PreferencesService _prefs;
  final GameConfig _config;
  final AnalyticsService _analytics;
  final bool Function() _removeAdsActive;
  final DateTime Function() _now;

  static const _interDayKey = 'ad_inter_day';
  static const _interCountKey = 'ad_inter_count';
  static const _resultDayKey = 'ad_result_inter_day';
  static const _resultCountKey = 'ad_result_inter_count';

  late final DateTime _sessionStart;
  DateTime? _lastInterstitialAt;
  bool _lastActionWasRewarded = false;

  final Map<RewardedPlacement, RewardedAd?> _rewarded = {};
  final Map<InterstitialPlacement, InterstitialAd?> _interstitials = {};
  final Map<RewardedPlacement, ValueNotifier<bool>> _ready = {
    for (final p in RewardedPlacement.values) p: ValueNotifier<bool>(false),
  };

  static Future<AdmobRewardGateway> create({
    required PreferencesService prefs,
    required GameConfig config,
    required AnalyticsService analytics,
    required bool Function() removeAdsActive,
  }) async {
    final gateway = AdmobRewardGateway(
      prefs: prefs,
      config: config,
      analytics: analytics,
      removeAdsActive: removeAdsActive,
    );
    try {
      await gateway._requestConsent();
      await MobileAds.instance.initialize();
      gateway._preloadAll();
    } catch (e) {
      if (kDebugMode) debugPrint('AdMob init failed — ads disabled: $e');
    }
    return gateway;
  }

  // ── UMP consent (also drives iOS ATT via the consent form) ───────────────
  Future<void> _requestConsent() {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        } catch (_) {}
        if (!completer.isCompleted) completer.complete();
      },
      (FormError _) {
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future;
  }

  /// Debug-only: wipe stored consent so the flow can be re-tested from scratch.
  void resetConsentForDebug() => ConsentInformation.instance.reset();

  void _preloadAll() {
    for (final p in RewardedPlacement.values) {
      _loadRewarded(p);
    }
    for (final p in InterstitialPlacement.values) {
      _loadInterstitial(p);
    }
  }

  // ── Rewarded ────────────────────────────────────────────────────────────
  void _loadRewarded(RewardedPlacement placement) {
    RewardedAd.load(
      adUnitId: Env.rewardedUnitId(placement.id),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded[placement] = ad;
          _ready[placement]!.value = true;
        },
        onAdFailedToLoad: (error) {
          _rewarded[placement] = null;
          _ready[placement]!.value = false;
        },
      ),
    );
  }

  @override
  ValueListenable<bool> isReady(RewardedPlacement placement) =>
      _ready[placement]!;

  @override
  Future<bool> showRewardedAd(RewardedPlacement placement) {
    final ad = _rewarded[placement];
    if (ad == null) return Future.value(false);

    final completer = Completer<bool>();
    var earned = false;

    // Consume the loaded instance immediately so it can't be shown twice.
    _rewarded[placement] = null;
    _ready[placement]!.value = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) =>
          _analytics.adImpression(format: 'rewarded', placementId: placement.id),
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _lastActionWasRewarded = earned;
        _loadRewarded(placement);
        if (!completer.isCompleted) completer.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _loadRewarded(placement);
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    ad.show(onUserEarnedReward: (_, reward) {
      earned = true;
      _analytics.adRewardGranted(placementId: placement.id);
    });
    return completer.future;
  }

  // ── Interstitial ──────────────────────────────────────────────────────────
  void _loadInterstitial(InterstitialPlacement placement) {
    InterstitialAd.load(
      adUnitId: Env.interstitialUnitId(placement.id),
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitials[placement] = ad,
        onAdFailedToLoad: (_) => _interstitials[placement] = null,
      ),
    );
  }

  @override
  Future<void> showInterstitial(InterstitialPlacement placement) async {
    if (!_interstitialAllowed(placement)) return;
    final ad = _interstitials[placement];
    if (ad == null) return;

    _interstitials[placement] = null;
    final completer = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) => _analytics.adImpression(
        format: 'interstitial',
        placementId: placement.id,
      ),
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _recordInterstitialShown(placement);
        _loadInterstitial(placement);
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _loadInterstitial(placement);
        if (!completer.isCompleted) completer.complete();
      },
    );
    await ad.show();
    return completer.future;
  }

  /// Enforces every interstitial frequency rule. Consumes the
  /// "never right after a rewarded ad" flag so it blocks exactly one follow-up.
  bool _interstitialAllowed(InterstitialPlacement placement) {
    if (_removeAdsActive()) return false;
    final now = _now();
    if (now.difference(_sessionStart).inSeconds <
        _config.interstitialSessionWarmupSeconds) {
      return false;
    }
    if (_lastActionWasRewarded) {
      _lastActionWasRewarded = false;
      return false;
    }
    if (_lastInterstitialAt != null &&
        now.difference(_lastInterstitialAt!).inSeconds <
            _config.interstitialMinGapSeconds) {
      return false;
    }
    if (_dailyCount(_interDayKey, _interCountKey) >=
        _config.interstitialDailyCap) {
      return false;
    }
    if (placement == InterstitialPlacement.result &&
        _dailyCount(_resultDayKey, _resultCountKey) >=
            _config.resultInterstitialDailyCap) {
      return false;
    }
    return true;
  }

  void _recordInterstitialShown(InterstitialPlacement placement) {
    _lastInterstitialAt = _now();
    _bumpDaily(_interDayKey, _interCountKey);
    if (placement == InterstitialPlacement.result) {
      _bumpDaily(_resultDayKey, _resultCountKey);
    }
  }

  int _dailyCount(String dayKey, String countKey) =>
      _prefs.getString(dayKey) == _todayKey() ? _prefs.getInt(countKey) : 0;

  void _bumpDaily(String dayKey, String countKey) {
    final current = _dailyCount(dayKey, countKey);
    _prefs.setString(dayKey, _todayKey());
    _prefs.setInt(countKey, current + 1);
  }

  String _todayKey() {
    final n = _now();
    return '${n.year}-${n.month}-${n.day}';
  }
}
