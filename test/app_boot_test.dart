import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:word_game/core/config/game_config.dart';
import 'package:word_game/core/di/service_locator.dart';
import 'package:word_game/data/dictionary_datasource.dart';
import 'package:word_game/features/daily/presentation/daily_cubit.dart';
import 'package:word_game/features/daily/presentation/daily_state.dart';

/// Boots the real DI graph (including async loading of the bundled dictionary
/// assets) and drives a daily load — a smoke test that the whole wiring holds
/// together against real word data.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    await sl.reset();
  });

  tearDown(() => sl.reset());

  testWidgets('DI resolves and the daily loads against the real dictionary', (
    tester,
  ) async {
    await configureDependencies();

    // The production dictionary finished loading its bundled assets.
    final answersEasy =
        sl<SupabaseAssetDictionary>().answersForTier(PracticeTier.easy);
    expect(answersEasy, isNotEmpty);

    final cubit = sl<DailyCubit>();
    await cubit.load();
    expect(cubit.state.phase, isNot(DailyPhase.loading));
    expect(cubit.state.answer, hasLength(5));
    expect(cubit.state.puzzleNumber, greaterThan(0));
    await cubit.close();
  });
}
