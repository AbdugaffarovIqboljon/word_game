import 'package:flutter/foundation.dart';

/// Serializes the daily board's first-run surfaces so they never race (WS3).
///
/// On a fresh first session several things want the screen at once: the
/// rules/coach flow and the theme-hint card's free auto-show. Left to their own
/// post-frame callbacks they overlap — the theme card would burn its 5-second
/// window (and the one-time free-show flag it consumes) while a rules sheet or
/// coach scrim is covering the board.
///
/// This coordinator gates the theme hint behind those blocking surfaces:
///
///   1. Each blocking surface (rules sheet, spotlight tour) registers itself
///      with [begin] while visible and [end] when dismissed.
///   2. The page calls [seal] once it has decided which first-run surfaces (if
///      any) will run — so a returning user with nothing queued releases the
///      hint immediately, while a first-run user waits.
///   3. [themeHintReady] flips true only when the queue is sealed *and* no
///      blocker is active — i.e. rules/coach first, then and only then the
///      theme card. The banner listens to it and starts its timer (and consumes
///      the free-show flag) at that moment, never while preempted.
class FirstRunOverlayCoordinator {
  final Set<Object> _blockers = {};
  bool _sealed = false;

  /// Whether the theme hint's free auto-show may start now: the first-run queue
  /// is sealed and nothing is covering the board.
  final ValueNotifier<bool> themeHintReady = ValueNotifier(false);

  /// Registers a blocking first-run surface as visible.
  void begin(Object surface) {
    _blockers.add(surface);
    _recompute();
  }

  /// Marks a blocking surface as dismissed.
  void end(Object surface) {
    _blockers.remove(surface);
    _recompute();
  }

  /// Declares that no further first-run surfaces will be enqueued. An empty
  /// queue releases the theme hint at once; otherwise it waits for [end].
  void seal() {
    if (_sealed) return;
    _sealed = true;
    _recompute();
  }

  void _recompute() {
    themeHintReady.value = _sealed && _blockers.isEmpty;
  }

  void dispose() => themeHintReady.dispose();
}
