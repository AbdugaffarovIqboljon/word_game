import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../tile_state.dart';
import 'static_tile.dart';

/// A single board tile bound to its own [ValueListenable] so a change to one
/// tile repaints only that tile.
///
/// Flip (component_spec (b)): when the bound state changes to a *revealed*
/// state, the tile runs a 150ms `rotateX 0→90→0`, swapping its face color at
/// the 50% keyframe (edge-on, so the swap is imperceptible). Typing/empty
/// changes update instantly with no flip. The 100ms per-tile stagger is applied
/// by the [BoardController] (it delays each column's reveal), so each tile just
/// animates its own flip.
///
/// Letter font is exactly half the tile size at every context (56→28, 52→26,
/// 42→21, 30→15).
class LetterTile extends StatefulWidget {
  const LetterTile({required this.data, required this.size, super.key});

  final ValueListenable<TileData> data;
  final double size;

  @override
  State<LetterTile> createState() => _LetterTileState();
}

class _LetterTileState extends State<LetterTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 150),
  )..addListener(_onFlipTick);

  late TileData _shown = widget.data.value;
  TileData _pending = const TileData.empty();
  bool _swapped = true;

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

  @override
  void dispose() {
    widget.data.removeListener(_onData);
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _flip,
      builder: (context, _) {
        final v = _flip.value;
        // 0→90° over the first half, 90°→0 over the second (never mirrored).
        final angle = (v < 0.5 ? v : 1 - v) * math.pi;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(angle),
          child: StaticTile(data: _shown, size: widget.size),
        );
      },
    );
  }
}
