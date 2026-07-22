import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:word_game/core/game/domain/guess.dart';
import 'package:word_game/core/game/domain/letter_result.dart';
import 'package:word_game/core/game/domain/word_tokenizer.dart';
import 'package:word_game/features/daily/presentation/widgets/fail_view.dart';

/// WS2 — the countdown box + share button result row must not overflow on
/// narrow devices, including at an enlarged system text scale.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final answer = WordTokenizer.tokenize('qalam');
  final guesses = [
    Guess(
      letters: WordTokenizer.tokenize('kitob'),
      results: const [
        LetterResult.absent,
        LetterResult.absent,
        LetterResult.present,
        LetterResult.absent,
        LetterResult.absent,
      ],
    ),
  ];

  Widget harness({required double width, required double textScale}) {
    return MediaQuery(
      data: MediaQueryData(
        size: Size(width, 800),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: MaterialApp(
          home: Scaffold(
            body: FailView(
              guesses: guesses,
              answer: answer,
              definition: 'Yozuv quroli',
              remaining: () => const Duration(hours: 8, minutes: 8, seconds: 8),
              onShare: () {},
            ),
          ),
        ),
      ),
    );
  }

  for (final width in [360.0, 390.0, 412.0]) {
    testWidgets('no overflow at ${width}px (fontScale 1.0)', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(harness(width: width, textScale: 1.0));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('no overflow at 360px with system fontScale 1.3', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness(width: 360, textScale: 1.3));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
