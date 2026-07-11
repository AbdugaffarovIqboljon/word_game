/// App-wide analytics contract. The full So'z Jangi event taxonomy lives here as
/// typed methods so call sites are compile-checked and event/param names cannot
/// drift. The production sink is [FirebaseAnalyticsService]; unit tests and any
/// build where Firebase failed to initialise get [NoopAnalyticsService].
///
/// Methods are fire-and-forget (`void`): logging must never block gameplay and a
/// dropped event is never worth an await at a call site.
abstract interface class AnalyticsService {
  /// App opened / brought to foreground into a fresh session.
  void sessionStart();

  /// A game began. [mode] is `daily` or `practice`.
  void gameStart({required String mode});

  /// A game finished. [result] is `win` or `loss`; [durationSeconds] is wall
  /// time from first interaction to resolution.
  void gameEnd({
    required String mode,
    required String result,
    required int attempts,
    required int durationSeconds,
  });

  /// A full-screen ad was shown. [format] is `rewarded` or `interstitial`.
  void adImpression({required String format, required String placementId});

  /// A rewarded ad completed and the reward was granted.
  void adRewardGranted({required String placementId});

  /// An in-app purchase completed for [sku].
  void iapPurchase({required String sku});

  /// A wallet mutation. [direction] is `credit` or `debit`; [amount] is the
  /// absolute value; [currency] is `coins` or `gems`; [source] is the reason.
  void economyTx({
    required String currency,
    required int amount,
    required String direction,
    required String source,
  });

  /// Retention funnel milestones.
  void funnelDailyStart();
  void funnelDailyComplete();
  void funnelShare();
  void funnelPracticeStart();

  /// A hint was consumed. [type] is the [_HintType]-style key (e.g. `reveal`).
  void funnelHintUsed({required String type});

  /// A cross-promotion surface was tapped.
  void crosspromoClick({String? target});
}

/// No-op sink: used in tests and whenever Firebase is unavailable. Every method
/// is a cheap no-op so call sites need no null checks or feature flags.
class NoopAnalyticsService implements AnalyticsService {
  const NoopAnalyticsService();

  @override
  void sessionStart() {}
  @override
  void gameStart({required String mode}) {}
  @override
  void gameEnd({
    required String mode,
    required String result,
    required int attempts,
    required int durationSeconds,
  }) {}
  @override
  void adImpression({required String format, required String placementId}) {}
  @override
  void adRewardGranted({required String placementId}) {}
  @override
  void iapPurchase({required String sku}) {}
  @override
  void economyTx({
    required String currency,
    required int amount,
    required String direction,
    required String source,
  }) {}
  @override
  void funnelDailyStart() {}
  @override
  void funnelDailyComplete() {}
  @override
  void funnelShare() {}
  @override
  void funnelPracticeStart() {}
  @override
  void funnelHintUsed({required String type}) {}
  @override
  void crosspromoClick({String? target}) {}
}
