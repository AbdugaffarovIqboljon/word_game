import 'package:flutter_test/flutter_test.dart';
import 'package:word_game/features/daily/presentation/first_run_overlay_coordinator.dart';

/// WS3 — the coordinator enforces first-run order: the theme hint is released
/// only after the queue is sealed *and* every blocking surface has been
/// dismissed (rules/coach first). Its `themeHintReady` gate is what the banner
/// uses to decide whether to burn its free show.
void main() {
  test('nothing queued: sealing releases the theme hint immediately', () {
    final c = FirstRunOverlayCoordinator();
    expect(c.themeHintReady.value, isFalse); // not yet decided
    c.seal();
    expect(c.themeHintReady.value, isTrue);
    c.dispose();
  });

  test('a blocking surface holds the hint until it is dismissed', () {
    final c = FirstRunOverlayCoordinator();
    c.begin('tour');
    c.seal();
    // Queue sealed but the tour is still up → hint stays gated (rules/coach
    // first).
    expect(c.themeHintReady.value, isFalse);

    c.end('tour');
    expect(c.themeHintReady.value, isTrue);
    c.dispose();
  });

  test('the hint waits for every registered surface', () {
    final c = FirstRunOverlayCoordinator();
    c.begin('rules');
    c.begin('tour');
    c.seal();
    expect(c.themeHintReady.value, isFalse);

    c.end('rules');
    expect(c.themeHintReady.value, isFalse); // tour still active

    c.end('tour');
    expect(c.themeHintReady.value, isTrue);
    c.dispose();
  });

  test('sealing before a surface is registered still gates correctly', () {
    final c = FirstRunOverlayCoordinator();
    // A blocker registered synchronously at decision time, then sealed in the
    // same pass — mirrors the daily page's _sync ordering.
    c.begin('rules');
    c.seal();
    expect(c.themeHintReady.value, isFalse);
    c.end('rules');
    expect(c.themeHintReady.value, isTrue);
    c.dispose();
  });
}
