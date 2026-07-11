import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import 'game_config.dart';

/// Fetches the remote overrides for [GameConfig] on launch.
///
/// Every economy number and ad-frequency cap in [GameConfig.tunables] becomes
/// remotely tunable: defaults are seeded from the current constants, so an
/// un-overridden key reads back its own default and nothing changes. Fetch is
/// cached for 12h (Firebase throttles more aggressive intervals in release
/// anyway). Any failure — Firebase absent, no network, throttled — yields an
/// empty map so [GameConfig] falls back to its baked-in constants.
class RemoteConfigService {
  const RemoteConfigService._();

  static Future<Map<String, Object>> fetchOverrides({
    required bool firebaseAvailable,
    GameConfig defaults = const GameConfig(),
  }) async {
    if (!firebaseAvailable) return const {};
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 12),
        ),
      );
      await rc.setDefaults(<String, dynamic>{
        for (final e in defaults.tunables.entries) e.key: e.value,
      });
      await rc.fetchAndActivate();
      // Read every registered key back as a number. Values equal to the seeded
      // default are harmless (GameConfig yields the same result either way).
      return <String, Object>{
        for (final key in defaults.tunables.keys)
          key: rc.getValue(key).asDouble(),
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('RemoteConfig unavailable — using local defaults: $e');
      }
      return const {};
    }
  }
}
