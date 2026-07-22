import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:word_game/core/game/presentation/skin_background.dart';
import 'package:word_game/core/game/presentation/tile_skin.dart';

/// WS4 — every non-default skin carries a procedural pattern + accent, and the
/// board background is a RepaintBoundary-isolated CustomPaint so tile flips
/// never repaint it (Standart stays a pure pass-through, no extra layer).
void main() {
  test('each catalog skin maps to its pattern + a non-neutral accent', () {
    expect(TileSkin.byId('standart').pattern, SkinPattern.none);
    expect(TileSkin.byId('milliy').pattern, SkinPattern.girih);
    expect(TileSkin.byId('neon').pattern, SkinPattern.neonGrid);
    expect(TileSkin.byId('oltin').pattern, SkinPattern.oltinShimmer);

    for (final id in ['milliy', 'neon', 'oltin']) {
      expect(TileSkin.byId(id).accent, isNot(TileSkin.standart.accent),
          reason: '$id must have a distinct ambient accent');
    }
    // Unknown ids fall back to Standart.
    expect(TileSkin.byId('???').pattern, SkinPattern.none);
  });

  testWidgets('Standart is a pass-through (no painter layer)', (tester) async {
    await tester.pumpWidget(
      SkinBackground(
        skin: TileSkin.byId('standart'),
        child: const SizedBox(key: Key('board')),
      ),
    );
    expect(find.byType(CustomPaint), findsNothing);
    expect(find.byKey(const Key('board')), findsOneWidget);
  });

  testWidgets('a patterned skin isolates the painter in a RepaintBoundary',
      (tester) async {
    await tester.pumpWidget(
      SkinBackground(
        skin: TileSkin.byId('oltin'),
        child: const SizedBox(key: Key('board')),
      ),
    );
    expect(find.byType(RepaintBoundary), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(RepaintBoundary),
        matching: find.byType(CustomPaint),
      ),
      findsWidgets,
    );
    expect(find.byKey(const Key('board')), findsOneWidget);
  });

  test('the pattern painter only repaints when the skin changes', () {
    const a = SkinPatternPainter(pattern: SkinPattern.girih, tint: Color(0xFF2E8B8B));
    const b = SkinPatternPainter(pattern: SkinPattern.girih, tint: Color(0xFF2E8B8B));
    const c = SkinPatternPainter(pattern: SkinPattern.neonGrid, tint: Color(0xFF2E8B8B));
    expect(a.shouldRepaint(b), isFalse); // identical skin → no repaint on flip
    expect(a.shouldRepaint(c), isTrue);
  });
}
