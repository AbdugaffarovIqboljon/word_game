import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_radii.dart';
import '../board_controller.dart';
import '../tile_state.dart';
import 'letter_tile.dart';

/// One board row of [LetterTile]s that can shake, bounce, highlight the live
/// row, and pulse its next-empty tile.
///
/// * **Shake** (component_spec (b) / decisions §6): 500ms single-shot, ±8px,
///   whole-row horizontal translate.
/// * **Win bounce** (component_spec motion): per-tile `translateY -6px` with an
///   80ms left-to-right stagger, single-shot.
/// * **Active-position feedback**: when this is the live row its empty tiles
///   brighten (via [LetterTile.activeRow]) and the next-empty tile gets a soft
///   pulsing halo.
class BoardRow extends StatefulWidget {
  const BoardRow({
    required this.rowIndex,
    required this.tiles,
    required this.shake,
    required this.bounce,
    required this.cursor,
    required this.tileSize,
    required this.gap,
    super.key,
  });

  final int rowIndex;
  final List<ValueListenable<TileData>> tiles;
  final ValueListenable<int> shake;
  final ValueListenable<int> bounce;
  final ValueListenable<BoardCursor> cursor;
  final double tileSize;
  final double gap;

  @override
  State<BoardRow> createState() => _BoardRowState();
}

class _BoardRowState extends State<BoardRow> with TickerProviderStateMixin {
  static const int _bounceStaggerMs = 80;
  static const int _bounceTileMs = 200;

  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: Duration(
      milliseconds: (widget.tiles.length - 1) * _bounceStaggerMs + _bounceTileMs,
    ),
  );

  @override
  void initState() {
    super.initState();
    widget.shake.addListener(_onShake);
    widget.bounce.addListener(_onBounce);
  }

  @override
  void didUpdateWidget(covariant BoardRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shake != widget.shake) {
      oldWidget.shake.removeListener(_onShake);
      widget.shake.addListener(_onShake);
    }
    if (oldWidget.bounce != widget.bounce) {
      oldWidget.bounce.removeListener(_onBounce);
      widget.bounce.addListener(_onBounce);
    }
  }

  void _onShake() => _shake.forward(from: 0);
  void _onBounce() => _bounce.forward(from: 0);

  @override
  void dispose() {
    widget.shake.removeListener(_onShake);
    widget.bounce.removeListener(_onBounce);
    _shake.dispose();
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final columns = widget.tiles.length;
    final stride = widget.tileSize + widget.gap;
    return ValueListenableBuilder<BoardCursor>(
      valueListenable: widget.cursor,
      builder: (context, cursor, _) {
        final isActiveRow = cursor.row == widget.rowIndex;
        final showHalo =
            isActiveRow && cursor.col >= 0 && cursor.col < columns;

        final tiles = <Widget>[
          for (var c = 0; c < columns; c++)
            LetterTile(
              data: widget.tiles[c],
              size: widget.tileSize,
              activeRow: isActiveRow,
            ),
        ];

        final stack = Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedBuilder(
              animation: _bounce,
              builder: (context, _) {
                final t = _bounce.isAnimating ? _bounce.value : 0.0;
                final children = <Widget>[];
                for (var c = 0; c < columns; c++) {
                  if (c > 0) children.add(SizedBox(width: widget.gap));
                  final dy = _bounceOffset(t, c, columns);
                  children.add(
                    dy == 0
                        ? tiles[c]
                        : Transform.translate(
                            offset: Offset(0, dy),
                            child: tiles[c],
                          ),
                  );
                }
                return Row(mainAxisSize: MainAxisSize.min, children: children);
              },
            ),
            if (showHalo)
              Positioned(
                left: cursor.col * stride,
                top: 0,
                child: _CursorHalo(size: widget.tileSize),
              ),
          ],
        );

        return AnimatedBuilder(
          animation: _shake,
          child: stack,
          builder: (context, child) => Transform.translate(
            offset: Offset(_shakeOffset(_shake.value), 0),
            child: child,
          ),
        );
      },
    );
  }

  /// Per-tile vertical bounce offset. Tile [col] rises over a 200ms window that
  /// starts [_bounceStaggerMs]·col into the sequence.
  double _bounceOffset(double t, int col, int columns) {
    if (t <= 0 || t >= 1) return 0;
    final total = (columns - 1) * _bounceStaggerMs + _bounceTileMs;
    final elapsed = t * total;
    final start = col * _bounceStaggerMs;
    final local = (elapsed - start) / _bounceTileMs;
    if (local <= 0 || local >= 1) return 0;
    return -6 * math.sin(math.pi * local);
  }
}

/// Soft pulsing border drawn over the next-empty tile in the live row.
class _CursorHalo extends StatefulWidget {
  const _CursorHalo({required this.size});

  final double size;

  @override
  State<_CursorHalo> createState() => _CursorHaloState();
}

class _CursorHaloState extends State<_CursorHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  late final Animation<double> _t = CurvedAnimation(
    parent: _pulse,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, _) {
          final color = Color.lerp(
            AppColors.tileFilledBorder,
            AppColors.tileCursorBorder,
            _t.value,
          )!;
          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              borderRadius: AppRadii.tileR,
              border: Border.all(color: color, width: 2),
            ),
          );
        },
      ),
    );
  }
}

/// Piecewise-linear shake curve from the source `@keyframes shake`
/// (decisions §6): 0→0, .1→-2, .2→4, .3→-8, .4→8, .5→-8, .6→8, .7→-8, .8→4,
/// .9→-2, 1→0.
double _shakeOffset(double t) {
  const keys = <double>[0, -2, 4, -8, 8, -8, 8, -8, 4, -2, 0];
  if (t <= 0) return keys.first;
  if (t >= 1) return keys.last;
  final scaled = t * (keys.length - 1);
  final i = scaled.floor();
  final frac = scaled - i;
  return keys[i] + (keys[i + 1] - keys[i]) * frac;
}
