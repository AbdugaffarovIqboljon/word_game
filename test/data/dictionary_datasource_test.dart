import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_game/core/config/game_config.dart';
import 'package:word_game/core/game/domain/word_tokenizer.dart';
import 'package:word_game/data/dictionary_datasource.dart';

/// Loads the real gzipped assets straight from disk so the test exercises the
/// actual bundled content (no rootBundle/manifest dependency).
class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = await File(key).readAsBytes();
    return ByteData.view(Uint8List.fromList(bytes).buffer);
  }
}

void main() {
  // Offline: an unroutable Supabase URL so refresh fails fast and we fall back
  // to the bundled schedule (exactly the offline-first path we care about).
  Future<SupabaseAssetDictionary> build() => SupabaseAssetDictionary.create(
        supabaseUrl: 'http://127.0.0.1:1',
        supabaseAnonKey: 'test',
        bundle: _DiskBundle(),
        networkTimeout: const Duration(milliseconds: 200),
      );

  test('loads bundled assets and validates real words offline', () async {
    final dict = await build();

    // Answers are a subset of valid guesses, so known answers are accepted.
    expect(dict.contains(WordTokenizer.tokenize('shahar')), isTrue);
    expect(dict.contains(WordTokenizer.tokenize('kitob')), isTrue);

    // Non-words are rejected.
    expect(dict.contains(WordTokenizer.tokenize('qwxyz')), isFalse);
  });

  test('answerForDate serves the bundled schedule, then cycles the pool', () async {
    final dict = await build();

    // 2026-07-10 is the first scheduled day (see generated schedule).
    final scheduled = dict.answerForDate(DateTime.utc(2026, 7, 10));
    expect(scheduled.map((l) => l.value).join(), 'ustod');

    // A date far outside the 90-day window still returns a real pool word.
    final beyond = dict.answerForDate(DateTime.utc(2035, 1, 1));
    expect(beyond, isNotEmpty);
    expect(dict.contains(beyond), isTrue);
  });

  test('puzzle number is 1 at launch epoch and monotonic', () async {
    final dict = await build();
    final n0 = dict.puzzleNumberForDate(DateTime.utc(2026, 7, 10));
    final n1 = dict.puzzleNumberForDate(DateTime.utc(2026, 7, 11));
    expect(n0, 1);
    expect(n1, n0 + 1);
  });

  test('practice tiers are populated', () async {
    final dict = await build();
    for (final tier in PracticeTier.values) {
      final pool = dict.answersForTier(tier);
      expect(pool, isNotEmpty, reason: 'tier $tier should have answers');
      expect(pool.every((w) => w.length == 5), isTrue);
    }
  });
}
