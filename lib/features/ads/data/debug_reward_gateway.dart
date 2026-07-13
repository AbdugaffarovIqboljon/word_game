import 'package:flutter/foundation.dart';

import '../../../core/app_navigator.dart';
import '../domain/reward_gateway.dart';
import '../presentation/simulated_ad.dart';

/// Debug fake used when [Env.useFakeAds] is on (all debug builds, all tests):
/// interstitials are no-ops and every placement reports ready so the UI shows
/// all ad-offer buttons.
///
/// A rewarded ad presents a **simulated** full-screen ad (a short watch-then-
/// reward flow) before granting, so device testing behaves like release instead
/// of crediting coins instantly. When no navigator/overlay is available (unit
/// tests, headless), it grants immediately so tests stay synchronous and fast.
class DebugRewardGateway implements RewardGateway {
  const DebugRewardGateway();

  static final ValueNotifier<bool> _alwaysReady = ValueNotifier<bool>(true);

  @override
  Future<bool> showRewardedAd(RewardedPlacement placement) async {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return true; // no UI (tests) → grant instantly
    await showSimulatedRewardedAd(context);
    return true;
  }

  @override
  Future<void> showInterstitial(InterstitialPlacement placement) async {}

  @override
  ValueListenable<bool> isReady(RewardedPlacement placement) => _alwaysReady;
}
