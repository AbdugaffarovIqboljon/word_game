import 'package:flutter/foundation.dart';

/// Rewarded-ad placements. [id] is the AdMob unit key resolved via `Env`.
enum RewardedPlacement {
  hintLetter('sj_hint_letter'),
  hintClean('sj_hint_clean'),
  chestDouble('sj_chest_double'),
  freezeFree('sj_freeze_free');

  const RewardedPlacement(this.id);
  final String id;
}

/// Interstitial placements. [id] is the AdMob unit key resolved via `Env`.
enum InterstitialPlacement {
  practice('sj_practice_inter'),
  result('sj_result_inter');

  const InterstitialPlacement(this.id);
  final String id;
}

/// Abstraction over the ad SDK. v1 debug ships [DebugRewardGateway]; release
/// ships `AdmobRewardGateway`. Hints, the streak ×2 chest, the freeze "watch ad"
/// option and the practice/result interstitials all go through this.
abstract interface class RewardGateway {
  /// Shows a rewarded ad for [placement]; resolves `true` only if the reward was
  /// earned (ad watched to completion), `false` if dismissed early / no fill.
  Future<bool> showRewardedAd(RewardedPlacement placement);

  /// Shows a full-screen interstitial (no reward) for [placement]. The
  /// implementation enforces frequency caps and may silently skip; resolves when
  /// done either way.
  Future<void> showInterstitial(InterstitialPlacement placement);

  /// Whether a rewarded ad for [placement] is loaded and showable right now.
  /// Ad-offer buttons listen to this and hide themselves on no-fill.
  ValueListenable<bool> isReady(RewardedPlacement placement);
}

/// Debug fake used when [Env.useFakeAds] is on (all debug builds, all tests):
/// rewarded ads always succeed, interstitials are no-ops, and every placement
/// reports ready so the UI shows all ad-offer buttons.
class DebugRewardGateway implements RewardGateway {
  const DebugRewardGateway();

  static final ValueNotifier<bool> _alwaysReady = ValueNotifier<bool>(true);

  @override
  Future<bool> showRewardedAd(RewardedPlacement placement) async => true;

  @override
  Future<void> showInterstitial(InterstitialPlacement placement) async {}

  @override
  ValueListenable<bool> isReady(RewardedPlacement placement) => _alwaysReady;
}
