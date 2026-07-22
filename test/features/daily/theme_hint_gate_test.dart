import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:word_game/features/practice/presentation/widgets/practice_theme_banner.dart';

/// WS3 — the theme banner's free auto-show is gated: it must not start its
/// window (nor consume the free-show flag via onAutoShown) while a first-run
/// surface is up, and must fire exactly once when the gate opens.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget harness(ValueNotifier<bool> gate, VoidCallback onAutoShown) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: PracticeThemeBanner(
              theme: 'Asbob',
              roundNonce: 1,
              reexpandCost: 5,
              initialSeconds: 1,
              reexpandSeconds: 1,
              autoShowGate: gate,
              onAutoShown: onAutoShown,
              onReexpand: (show) async => false,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('gated shut: the free show never starts (flag preserved)',
      (tester) async {
    final gate = ValueNotifier(false);
    var autoShown = 0;
    await tester.pumpWidget(harness(gate, () => autoShown++));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    // Preempted the whole time → the free-show flag is never consumed.
    expect(autoShown, 0);
    // Unmount the banner within an active frame before the tree finalizes.
    await tester.pumpWidget(const SizedBox());
    gate.dispose();
  });

  testWidgets('opening the gate fires the free show exactly once',
      (tester) async {
    final gate = ValueNotifier(false);
    var autoShown = 0;
    await tester.pumpWidget(harness(gate, () => autoShown++));
    await tester.pump();
    expect(autoShown, 0);

    // Rules/coach flow finishes → gate opens.
    gate.value = true;
    await tester.pump();
    expect(autoShown, 1);

    // Let the hold timer + collapse animation drain, then confirm it does not
    // re-consume the flag.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(autoShown, 1);
    await tester.pumpWidget(const SizedBox());
    gate.dispose();
  });
}
