import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_game/core/storage/preferences_service.dart';
import 'package:word_game/features/practice/data/practice_repository.dart';
import 'package:word_game/features/practice/domain/practice_session.dart';
import 'package:word_game/features/practice/presentation/practice_hub_page.dart';

/// WS5: the hub's "Bugungi sessiya" row is bound to [PracticeRepository.current],
/// so a practice solve is reflected immediately — no app restart, no re-navigation.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late PreferencesService prefs;
  late PracticeRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await PreferencesService.create();
    repo = PracticeRepository(prefs);
  });

  testWidgets('session row updates live when a practice game is solved',
      (tester) async {
    final today = DateTime.utc(2026, 7, 13);
    final session = repo.loadFor(today); // seeds repo.current with an empty day

    // Pump exactly the hub's live binding.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder<PracticeSession>(
            valueListenable: repo.current,
            builder: (_, s, _) => SessionRow(session: s),
          ),
        ),
      ),
    );

    // Fresh session: 0 solved, 0% accuracy.
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('100%'), findsNothing);

    // A game ends (as PracticeCubit does): persist a solved round.
    await repo.save(session.recordSolved(20));
    await tester.pump();

    // The row reflects it without any rebuild trigger from outside.
    expect(find.text('1'), findsOneWidget); // solved
    expect(find.text('100%'), findsOneWidget); // accuracy
    expect(find.text('20'), findsOneWidget); // coins
    expect(find.text('0%'), findsNothing);
  });
}
