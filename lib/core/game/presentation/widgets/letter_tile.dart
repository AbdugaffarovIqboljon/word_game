import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../tile_state.dart';
import 'static_tile.dart';

/// A single board tile bound to its own [ValueListenable] so a change to one
/// tile repaints only that tile.
///
/// Three motions, all local to the tile:
/// * **Flip** — when the bound state changes to a *revealed* state, a 150ms
///   `rotateX 0→90→0` swaps the face color at the 50% keyframe (edge-on, so the
///   swap is imperceptible). The 100ms per-tile stagger is applied by the
///   [BoardController].
/// * **Type pop** — an empty tile receiving a letter scales `1→1.08→1` over
///   110ms, the letter appearing at the peak.
/// * **Backspace fade** — a filled tile being cleared quickly fades + shrinks
///   out before the empty face returns.
///
/// [activeRow] brightens the empty border for the live row (active-position
/// feedback). Letter font is exactly half the tile size at every context.
class LetterTile extends StatefulWidget {
  const LetterTile({
    required this.data,
    required this.size,
    this.activeRow = false,
    super.key,
  });

  final ValueListenable<TileData> data;
  final double size;
  final bool activeRow;

  @override
  State<LetterTile> createState() => _LetterTileState();
}

enum _Pop { none, add, remove }

class _LetterTileState extends State<LetterTile>
    with TickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  )..addListener(_onFlipTick);

  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
  )
    ..addListener(_onPopTick)
    ..addStatusListener(_onPopStatus);

  late TileData _shown = widget.data.value;
  TileData _pending = const TileData.empty();
  bool _swapped = true;
  _Pop _popMode = _Pop.none;

  @override
  void initState() {
    super.initState();
    widget.data.addListener(_onData);
  }

  @override
  void didUpdateWidget(covariant LetterTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      oldWidget.data.removeListener(_onData);
      widget.data.addListener(_onData);
      _shown = widget.data.value;
    }
  }

  void _onData() {
    final next = widget.data.value;
    if (next == _shown) return;
    if (next.state.isRevealed) {
      _pending = next;
      _swapped = false;
      _flip.forward(from: 0);
    } else if (next.state == TileState.typing &&
        _shown.state == TileState.empty) {
      // Letter added → pop; the letter appears at the scale peak (50%).
      _pending = next;
      _swapped = false;
      _popMode = _Pop.add;
      _pop.forward(from: 0);
    } else if (next.state == TileState.empty && _shown.letter != null) {
      // Backspace / clear → quick fade-out, then the empty face returns.
      _pending = next;
      _popMode = _Pop.remove;
      _pop.forward(from: 0);
    } else {
      setState(() => _shown = next);
    }
  }

  void _onFlipTick() {
    if (!_swapped && _flip.value >= 0.5) {
      _swapped = true;
      setState(() => _shown = _pending);
    }
  }

  void _onPopTick() {
    // Reveal a filled letter at the pop peak (mirrors the flip's 50% swap).
    if (_popMode == _Pop.add && !_swapped && _pop.value >= 0.5) {
      _swapped = true;
      setState(() => _shown = _pending);
    }
  }

  void _onPopStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (_popMode == _Pop.remove) setState(() => _shown = _pending);
    setState(() => _popMode = _Pop.none);
  }

  @override
  void dispose() {
    widget.data.removeListener(_onData);
    _flip.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_flip, _pop]),
      builder: (context, _) {
        final flipV = _flip.value;
        final angle = (flipV < 0.5 ? flipV : 1 - flipV) * math.pi;

        final t = _pop.value;
        var scale = 1.0;
        var opacity = 1.0;
        if (_popMode == _Pop.add) {
          scale = 1 + 0.08 * math.sin(math.pi * t);
        } else if (_popMode == _Pop.remove) {
          scale = 1 - 0.06 * t;
          opacity = 1 - t;
        }

        Widget face = Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(angle),
          child: StaticTile(
            data: _shown,
            size: widget.size,
            activeRow: widget.activeRow,
          ),
        );
        if (scale != 1.0) {
          face = Transform.scale(scale: scale, child: face);
        }
        if (opacity != 1.0) {
          face = Opacity(opacity: opacity, child: face);
        }
        return face;
      },
    );
  }
}
