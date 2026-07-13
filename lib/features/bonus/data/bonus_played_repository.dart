import '../../../core/storage/preferences_service.dart';

/// Persists the set of bonus words ("Yana yechish", WS3) the user has already
/// played, so a bonus word is never served to them twice. Keyed by the word's
/// tokenized key (the same key the dictionary uses), stored as a string list.
class BonusPlayedRepository {
  BonusPlayedRepository(this._prefs);

  static const _key = 'bonus_played_words';

  final PreferencesService _prefs;

  Set<String> load() => _prefs.getStringList(_key).toSet();

  bool contains(String wordKey) => _prefs.getStringList(_key).contains(wordKey);

  Future<void> add(String wordKey) {
    final set = load()..add(wordKey);
    return _prefs.setStringList(_key, set.toList());
  }
}
