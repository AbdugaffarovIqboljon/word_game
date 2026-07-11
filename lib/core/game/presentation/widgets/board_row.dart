import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../tile_state.dart';
import 'letter_tile.dart';

/// One board row of [LetterTile]s that can shake as a whole.
///
/// Shake (component_spec (b) / decisions §6): 500ms single-shot, ±8px, with the
/// source's exact keyframe curve. Bumping [shake] runs it once. Tiles are built
/// once (passed as the AnimatedBuilder child) so a shake only re-runs the
/// translate, never the tiles.
class BoardRow extends StatefulWidget {
  const BoardRow({
    required this.tiles,
    required this.shake,
    required this.tileSize,
    required this.gap,
    super.key,
  });

  final List<ValueListenable<TileData>> tiles;
  final ValueListenable<int> shake;
  final double tileSize;
  final double gap;

  @override
  State<BoardRow> createState() => _BoardRowState();
}

class _BoardRowState extends State<BoardRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  @override
  void initState() {
    super.initState();
    widget.shake.addListener(_onShake);
  }

  @override
  void didUpdateWidget(covariant BoardRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shake != widget.shake) {
      oldWidget.shake.removeListener(_onShake);
      widget.shake.addListener(_onShake);
    }
  }

  void _onShake() => _shake.forward(from: 0);

  @override
  void dispose() {
    widget.shake.removeListener(_onShake);
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var c = 0; c < widget.tiles.length; c++) {
      if (c > 0) children.add(SizedBox(width: widget.gap));
      children.add(LetterTile(data: widget.tiles[c], size: widget.tileSize));
    }
    return AnimatedBuilder(
      animation: _shake,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
      builder: (context, child) => Transform.translate(
        offset: Offset(_shakeOffset(_shake.value), 0),
        child: child,
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
