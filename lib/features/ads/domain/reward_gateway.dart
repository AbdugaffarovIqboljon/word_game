/// Abstraction over the ad SDK. Real rewarded/interstitial ads are a later work
/// package; v1 ships [DebugRewardGateway]. Hints, the streak ×2 chest, the
/// freeze "watch ad" option and the practice interstitial all go through this.
abstract interface class RewardGateway {
  /// Shows a rewarded ad; resolves `true` if the reward was earned (ad watched
  /// to completion), `false` if dismissed early / unavailable.
  Future<bool> showRewardedAd();

  /// Shows a full-screen interstitial (no reward). Resolves when dismissed.
  Future<void> showInterstitial();
}

/// Debug fake used until a real ad SDK is integrated: rewarded ads always
/// succeed, interstitials are instantaneous no-ops.
class DebugRewardGateway implements RewardGateway {
  const DebugRewardGateway();

  @override
  Future<bool> showRewardedAd() async => true;

  @override
  Future<void> showInterstitial() async {}
}
