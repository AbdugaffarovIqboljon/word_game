import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Brings Firebase up defensively.
///
/// [Firebase.initializeApp] is called WITHOUT generated options on purpose: it
/// reads the native `google-services.json` / `GoogleService-Info.plist` that the
/// owner adds via `flutterfire configure`. When those files are absent (a fresh
/// checkout, most debug runs) initialisation throws — we swallow it and report
/// `false` so the app transparently falls back to the no-op analytics sink and
/// the local RemoteConfig defaults. Firebase must never block or crash launch.
///
/// Returns `true` only when Firebase is live, in which case Crashlytics error
/// handlers are installed and collection is enabled outside debug.
Future<bool> bootstrapFirebase() async {
  try {
    await Firebase.initializeApp();
  } catch (e, s) {
    if (kDebugMode) {
      debugPrint('Firebase unavailable — running without it: $e\n$s');
    }
    return false;
  }

  try {
    final crashlytics = FirebaseCrashlytics.instance;
    // No crash reports off debug devices; owner data stays clean.
    await crashlytics.setCrashlyticsCollectionEnabled(!kDebugMode);

    // Route framework + platform (async/isolate) errors to Crashlytics while
    // preserving the default console print in debug.
    final priorOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      priorOnError?.call(details);
      crashlytics.recordFlutterFatalError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      crashlytics.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (e) {
    if (kDebugMode) debugPrint('Crashlytics wiring skipped: $e');
  }
  return true;
}
