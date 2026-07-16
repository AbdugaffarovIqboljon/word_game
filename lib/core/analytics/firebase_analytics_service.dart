import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';

import 'analytics_service.dart';

/// [AnalyticsService] backed by Firebase Analytics (GA4). Event and parameter
/// names follow the So'z Jangi taxonomy exactly. Each `logEvent` Future is
/// fired-and-forgotten so logging never blocks the UI; failures are swallowed
/// (analytics must never crash the app).
class FirebaseAnalyticsService implements AnalyticsService {
  FirebaseAnalyticsService(this._fa);

  final FirebaseAnalytics _fa;

  void _log(String name, [Map<String, Object>? params]) {
    unawaited(_fa.logEvent(name: name, parameters: params).catchError((_) {}));
  }

  @override
  void sessionStart() => _log('session_start');

  @override
  void gameStart({required String mode}) =>
      _log('game_start', {'mode': mode});

  @override
  void gameEnd({
    required String mode,
    required String result,
    required int attempts,
    required int durationSeconds,
  }) => _log('game_end', {
    'mode': mode,
    'result': result,
    'attempts': attempts,
    'duration': durationSeconds,
  });

  @override
  void adImpression({required String format, required String placementId}) =>
      _log('ad_impression', {'format': format, 'placement_id': placementId});

  @override
  void adRewardGranted({required String placementId}) =>
      _log('ad_reward_granted', {'placement_id': placementId});

  @override
  void iapPurchase({required String sku}) => _log('iap_purchase', {'sku': sku});

  @override
  void economyTx({
    required String currency,
    required int amount,
    required String direction,
    required String source,
  }) => _log('economy_tx', {
    'currency': currency,
    'amount': amount,
    'direction': direction,
    'source': source,
  });

  @override
  void funnelDailyStart() => _log('funnel_daily_start');

  @override
  void funnelDailyComplete() => _log('funnel_daily_complete');

  @override
  void funnelShare() => _log('funnel_share');

  @override
  void funnelPracticeStart() => _log('funnel_practice_start');

  @override
  void funnelHintUsed({required String type}) =>
      _log('funnel_hint_used', {'type': type});

  @override
  void crosspromoClick({String? target}) =>
      _log('crosspromo_click', target == null ? null : {'target': target});

  @override
  void wordRejected({
    required String word,
    required String mode,
    required String date,
  }) => _log('word_rejected', {'word': word, 'mode': mode, 'date': date});
}
