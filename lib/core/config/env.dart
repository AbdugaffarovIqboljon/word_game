/// Build-time environment configuration, supplied via `--dart-define`.
///
/// Empty defaults are intentional: the production [SupabaseAssetDictionary] runs
/// fully offline off its bundled assets (16k-word guess list + 90-day schedule),
/// and the Supabase refresh is stale-while-revalidate — a missing/invalid URL
/// just skips the network step. Provide real values in CI/release:
/// `--dart-define=SUPABASE_URL=… --dart-define=SUPABASE_ANON_KEY=…`.
abstract final class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );
}
