import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:word_game/core/config/game_config.dart';
import 'package:word_game/core/game/presentation/tile_skin.dart';
import 'package:word_game/features/shop/presentation/shop_page.dart';

/// WS5 — the skin preview (a fixed-aspect mini-board clipped to the card) must
/// not overflow at a 360px-class grid cell even at a large system font scale
/// (previously the preview clipped the card bottom by 26px).
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('skin previews do not overflow at 360px with fontScale 1.3',
      (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const config = GameConfig();
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: Center(
              // A shop grid cell is roughly half the 360px screen width.
              child: SizedBox(
                width: 164,
                child: ListView(
                  children: [
                    for (final sku in config.skins)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: SkinPreviewRow(skin: TileSkin.byId(sku.id)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
