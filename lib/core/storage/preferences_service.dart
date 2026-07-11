import 'package:shared_preferences/shared_preferences.dart';

/// Thin typed wrapper over [SharedPreferences]. The single low-level persistence
/// primitive shared by every feature (board state, streak, wallet, settings,
/// onboarding flag). Features layer their own typed repositories on top of this
/// rather than touching [SharedPreferences] directly.
class PreferencesService {
  PreferencesService(this._prefs);

  final SharedPreferences _prefs;

  /// Loads the platform store. Call once at startup before registering.
  static Future<PreferencesService> create() async =>
      PreferencesService(await SharedPreferences.getInstance());

  bool getBool(String key, {bool fallback = false}) =>
      _prefs.getBool(key) ?? fallback;
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  int getInt(String key, {int fallback = 0}) => _prefs.getInt(key) ?? fallback;
  Future<void> setInt(String key, int value) => _prefs.setInt(key, value);

  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  List<String> getStringList(String key) => _prefs.getStringList(key) ?? const [];
  Future<void> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  bool contains(String key) => _prefs.containsKey(key);
  Future<void> remove(String key) => _prefs.remove(key);
}
