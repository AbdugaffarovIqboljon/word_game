import 'dart:async';
import 'dart:convert';
import 'dart:io' show Directory, File, HttpClient, gzip;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../core/config/game_config.dart' show PracticeTier;
import '../core/game/domain/dictionary.dart';
import '../core/game/domain/logical_letter.dart';
import '../core/game/domain/word_tokenizer.dart';

/// Production [Dictionary]: the real word source that replaces
/// `InMemoryDictionary`.
///
/// * **Validation + answer lookup** come from gzipped assets bundled with the
///   app (built by `tool/corpus` + `tool/generator`):
///     - `valid_guesses.txt.gz`  — accepted-guess list (superset of answers)
///     - `answers_tiered.tsv.gz` — answer pool with a difficulty tier (practice)
///     - `schedule.json.gz`      — 90-day daily schedule (bundled offline source)
/// * **Daily** is server-authoritative (the `evaluate-guess` Edge Function via
///   `SupabaseDailyPuzzleRepository`); this class is Daily's *offline fallback*
///   data source — `FallbackDailyPuzzleRepository` reads `answerForDate` /
///   `puzzleNumberForDate` / `definitionFor` / `contains` from the bundled
///   schedule when the network is unavailable, so a date is *never* missing.
///
/// NB: the legacy Supabase REST refresh below targets the pre-normalisation flat
/// `daily_puzzles` table and no-ops against the current backend (the answer is no
/// longer client-readable). It is kept as a harmless, self-healing cache prime
/// and is only ever exercised offline-after-failure; the bundled schedule is the
/// real offline source.
///
/// Words tokenize through the app's own [WordTokenizer], so validity keys here
/// are identical to the keys the game engine computes for a player's guess.
///
/// Because [Dictionary] is fully synchronous, everything is resident in memory
/// before first use: call the async [create] factory once at startup. Network
/// refresh then happens out-of-band (stale-while-revalidate) and its failure is
/// always non-fatal. Register it as a drop-in for the in-memory fake:
///
/// ```dart
/// sl.registerSingletonAsync<Dictionary>(() => SupabaseAssetDictionary.create(
///   supabaseUrl: Env.supabaseUrl,
///   supabaseAnonKey: Env.supabaseAnonKey,
///   cacheDir: await getApplicationSupportDirectory(), // optional persistence
/// ));
/// ```
///
/// SDK-only (no new packages): assets via [AssetBundle], gzip + HTTP via
/// `dart:io`. `dart:io` targets mobile/desktop; a web build needs an html variant.
class SupabaseAssetDictionary implements Dictionary {
  SupabaseAssetDictionary._({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.cacheDir,
    required AssetBundle bundle,
    required HttpClient Function() httpClientFactory,
    required DateTime Function() nowUtc,
    required this.rolloverOffsetHours,
    required this.prefetchDays,
    required this.networkTimeout,
    required this.minRefreshInterval,
    required this.assetPrefix,
  })  : _bundle = bundle,
        _httpClientFactory = httpClientFactory,
        _nowUtc = nowUtc;

  /// Builds the dictionary, loads all assets + disk cache, and does a first
  /// (non-blocking-failure) network refresh. The returned instance is ready for
  /// synchronous use.
  static Future<SupabaseAssetDictionary> create({
    required String supabaseUrl,
    required String supabaseAnonKey,
    Directory? cacheDir,
    AssetBundle? bundle,
    HttpClient Function()? httpClientFactory,
    DateTime Function()? nowUtc,
    int rolloverOffsetHours = 5, // Tashkent, matches GameConfig
    int prefetchDays = 7,
    Duration networkTimeout = const Duration(seconds: 6),
    Duration minRefreshInterval = const Duration(hours: 6),
    String assetPrefix = 'assets/dictionary',
  }) async {
    final dict = SupabaseAssetDictionary._(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      cacheDir: cacheDir,
      bundle: bundle ?? rootBundle,
      httpClientFactory: httpClientFactory ?? HttpClient.new,
      nowUtc: nowUtc ?? (() => DateTime.now().toUtc()),
      rolloverOffsetHours: rolloverOffsetHours,
      prefetchDays: prefetchDays,
      networkTimeout: networkTimeout,
      minRefreshInterval: minRefreshInterval,
      assetPrefix: assetPrefix,
    );
    await dict._initialize();
    return dict;
  }

  final String supabaseUrl;
  final String supabaseAnonKey;
  final Directory? cacheDir;
  final AssetBundle _bundle;
  final HttpClient Function() _httpClientFactory;
  final DateTime Function() _nowUtc;
  final int rolloverOffsetHours;
  final int prefetchDays;
  final Duration networkTimeout;
  final Duration minRefreshInterval;
  final String assetPrefix;

  final Set<String> _validKeys = <String>{};
  final List<List<LogicalLetter>> _answerPool = <List<LogicalLetter>>[];
  final Map<PracticeTier, List<List<LogicalLetter>>> _answersByTier = {
    PracticeTier.easy: <List<LogicalLetter>>[],
    PracticeTier.medium: <List<LogicalLetter>>[],
    PracticeTier.hard: <List<LogicalLetter>>[],
  };
  final Map<String, _ScheduledPuzzle> _byDate = <String, _ScheduledPuzzle>{};
  final Map<String, String> _definitionByKey = <String, String>{};
  final Map<String, String> _themeByKey = <String, String>{};

  DateTime _launchEpoch = DateTime.utc(2024, 1, 1);
  int _launchNumber = 1; // puzzle_number of _launchEpoch (schedule start_number)
  DateTime? _lastRefreshAttempt;

  // --- Dictionary ---------------------------------------------------------

  @override
  bool contains(List<LogicalLetter> word) =>
      _validKeys.contains(WordTokenizer.keyOf(word));

  @override
  List<LogicalLetter> answerForDate(DateTime date) {
    // Stale-while-revalidate: serve resident data now, refresh in the background.
    unawaited(_maybeRefresh());
    final scheduled = _byDate[_dateKey(date)];
    if (scheduled != null) return scheduled.tokens;
    // Beyond the scheduled/cached window: deterministic cycle over the pool so a
    // date is never missing (mirrors InMemoryDictionary's index-by-day scheme).
    if (_answerPool.isEmpty) return const <LogicalLetter>[];
    return _answerPool[_dayIndex(date) % _answerPool.length];
  }

  @override
  String? definitionFor(List<LogicalLetter> word) =>
      _definitionByKey[WordTokenizer.keyOf(word)];

  @override
  String? themeFor(List<LogicalLetter> word) =>
      _themeByKey[WordTokenizer.keyOf(word)];

  @override
  int puzzleNumberForDate(DateTime date) {
    // Schedule is contiguous daily from _launchEpoch (= start_number), so this
    // equals the stored puzzle_number across the whole window and extends it
    // linearly beyond — matching daily_puzzles.puzzle_number on the server.
    final n = _launchNumber + _dayIndex(date);
    return n < 1 ? 1 : n;
  }

  // --- extras (beyond the interface, for Practice mode) -------------------

  /// Answer pool for practice mode, filtered to one difficulty tier.
  List<List<LogicalLetter>> answersForTier(PracticeTier tier) =>
      List.unmodifiable(_answersByTier[tier] ?? const []);

  /// Force a Supabase refresh of the rolling window (e.g. on app resume).
  Future<void> refresh() => _refreshWindow(force: true);

  void dispose() {}

  // --- init / asset loading ----------------------------------------------

  Future<void> _initialize() async {
    await Future.wait([_loadValidGuesses(), _loadAnswers(), _loadSchedule()]);
    await _loadDiskCache();
    await _maybeRefresh();
  }

  Future<String> _loadGzText(String name) async {
    final data = await _bundle.load('$assetPrefix/$name');
    final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    return utf8.decode(gzip.decode(bytes));
  }

  Future<void> _loadValidGuesses() async {
    final text = await _loadGzText('valid_guesses.txt.gz');
    for (final line in const LineSplitter().convert(text)) {
      if (line.isEmpty) continue;
      _validKeys.add(WordTokenizer.keyOf(WordTokenizer.tokenize(line)));
    }
  }

  Future<void> _loadAnswers() async {
    // answers_tiered.tsv.gz: word \t tier(1..3) \t freq \t theme \t definition
    // (WS-B: theme + definition cover EVERY answer, so the Mavzu and Lugʻat
    // hints work for the whole practice/bonus pool, not just scheduled words.)
    final text = await _loadGzText('answers_tiered.tsv.gz');
    for (final line in const LineSplitter().convert(text)) {
      if (line.isEmpty) continue;
      final parts = line.split('\t');
      if (parts.length < 2) continue;
      final tokens = WordTokenizer.tokenize(parts[0]);
      _answerPool.add(tokens);
      _answersByTier[_tierFrom(int.tryParse(parts[1]) ?? 2)]!.add(tokens);
      if (parts.length >= 5) {
        final key = WordTokenizer.keyOf(tokens);
        if (parts[3].isNotEmpty) _themeByKey[key] = parts[3];
        if (parts[4].isNotEmpty) _definitionByKey[key] = parts[4];
      }
    }
  }

  Future<void> _loadSchedule() async {
    final obj = jsonDecode(await _loadGzText('schedule.json.gz'))
        as Map<String, dynamic>;
    final start = obj['start_date'] as String?;
    if (start != null) _launchEpoch = _dayOnly(DateTime.parse(start));
    // Anchor puzzle numbering to the schedule's own start_number so the bundled
    // offline fallback reports the same puzzle_number as the server for a date.
    _launchNumber = (obj['start_number'] as num?)?.toInt() ?? 1;
    for (final p in (obj['puzzles'] as List).cast<Map<String, dynamic>>()) {
      _ingest(p);
    }
  }

  // --- caching ------------------------------------------------------------

  File? get _cacheFile => cacheDir == null
      ? null
      : File('${cacheDir!.path}/daily_puzzles_cache.json');

  Future<void> _loadDiskCache() async {
    final f = _cacheFile;
    if (f == null || !await f.exists()) return;
    try {
      final obj = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      for (final p in (obj['puzzles'] as List).cast<Map<String, dynamic>>()) {
        _ingest(p);
      }
    } catch (_) {
      // Corrupt cache is non-fatal — the bundled schedule still covers us.
    }
  }

  Future<void> _persistCache() async {
    final f = _cacheFile;
    if (f == null) return;
    try {
      await f.create(recursive: true);
      await f.writeAsString(jsonEncode({
        'puzzles': _byDate.values.map((p) => p.toJson()).toList(),
      }));
    } catch (_) {
      // Best-effort.
    }
  }

  // --- network ------------------------------------------------------------

  Future<void> _maybeRefresh() async {
    final last = _lastRefreshAttempt;
    final now = _nowUtc();
    if (last != null && now.difference(last) < minRefreshInterval) return;
    await _refreshWindow(force: false);
  }

  Future<void> _refreshWindow({required bool force}) async {
    final now = _nowUtc();
    if (!force) {
      final last = _lastRefreshAttempt;
      if (last != null && now.difference(last) < minRefreshInterval) return;
    }
    _lastRefreshAttempt = now;

    final from = _tashkentDate(now);
    final to = from.add(Duration(days: prefetchDays));
    final query = 'select=date,word,definition_uz,difficulty'
        '&date=gte.${_dateKey(from)}&date=lte.${_dateKey(to)}&order=date.asc';
    final uri = Uri.parse('$supabaseUrl/rest/v1/daily_puzzles?$query');

    final client = _httpClientFactory()..connectionTimeout = networkTimeout;
    try {
      final req = await client.getUrl(uri).timeout(networkTimeout);
      req.headers
        ..set('apikey', supabaseAnonKey)
        ..set('Authorization', 'Bearer $supabaseAnonKey')
        ..set('Accept', 'application/json');
      final resp = await req.close().timeout(networkTimeout);
      if (resp.statusCode != 200) return;
      final body =
          await resp.transform(utf8.decoder).join().timeout(networkTimeout);
      final rows = (jsonDecode(body) as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) return;
      for (final row in rows) {
        _ingest(row);
      }
      await _persistCache();
    } catch (_) {
      // Offline / server error: keep whatever cache + bundle we already have.
    } finally {
      client.close(force: true);
    }
  }

  // --- helpers ------------------------------------------------------------

  void _ingest(Map<String, dynamic> row) {
    final dateStr = row['date'] as String?;
    final word = row['word'] as String?;
    if (dateStr == null || word == null) return;
    final key = _dateKey(DateTime.parse(dateStr));
    final def = row['definition_uz'] as String?;
    final theme = row['theme'] as String?;
    final difficulty = (row['difficulty'] as num?)?.toInt() ?? 2;
    final tokens = WordTokenizer.tokenize(word);
    _byDate[key] = _ScheduledPuzzle(
      dateKey: key, tokens: tokens, definition: def, difficulty: difficulty);
    final wordKey = WordTokenizer.keyOf(tokens);
    if (def != null && def.isNotEmpty) _definitionByKey[wordKey] = def;
    if (theme != null && theme.isNotEmpty) _themeByKey[wordKey] = theme;
  }

  PracticeTier _tierFrom(int t) => switch (t) {
        1 => PracticeTier.easy,
        3 => PracticeTier.hard,
        _ => PracticeTier.medium,
      };

  /// "Today" in Tashkent time, as a date-only UTC instant (matches GameClock).
  DateTime _tashkentDate(DateTime nowUtc) {
    final local = nowUtc.add(Duration(hours: rolloverOffsetHours));
    return DateTime.utc(local.year, local.month, local.day);
  }

  static DateTime _dayOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);

  int _dayIndex(DateTime date) => _dayOnly(date).difference(_launchEpoch).inDays;

  String _dateKey(DateTime d) {
    final u = _dayOnly(d);
    return '${u.year.toString().padLeft(4, '0')}-'
        '${u.month.toString().padLeft(2, '0')}-'
        '${u.day.toString().padLeft(2, '0')}';
  }
}

class _ScheduledPuzzle {
  const _ScheduledPuzzle({
    required this.dateKey,
    required this.tokens,
    required this.definition,
    required this.difficulty,
  });

  final String dateKey;
  final List<LogicalLetter> tokens;
  final String? definition;
  final int difficulty;

  String get _word => tokens.map((l) => l.value).join();

  Map<String, dynamic> toJson() => {
        'date': dateKey,
        'word': _word,
        'definition_uz': definition,
        'difficulty': difficulty,
      };
}
