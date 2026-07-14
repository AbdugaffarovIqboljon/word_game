import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// Brings Supabase up defensively, mirroring `bootstrapFirebase`.
///
/// Daily mode's puzzle metadata and guess evaluation are server-authoritative
/// (see `DailyPuzzleRepository`), but a missing/blank config — an empty
/// `SUPABASE_URL`/`SUPABASE_ANON_KEY` because no `--dart-define` was passed —
/// must never crash launch. Returns `true` only when the client actually
/// initialized; the daily screen shows a retry-able error when it later can't
/// reach the backend, it never treats this as fatal.
Future<bool> bootstrapSupabase() async {
  if (Env.supabaseUrl.isEmpty || Env.supabaseAnonKey.isEmpty) return false;
  try {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
    );
    return true;
  } catch (e, s) {
    if (kDebugMode) {
      debugPrint('Supabase unavailable — daily mode will show a retry error: $e\n$s');
    }
    return false;
  }
}
