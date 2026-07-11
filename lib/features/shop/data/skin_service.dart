import 'package:flutter/foundation.dart';

import '../../../core/storage/preferences_service.dart';

/// Owns the active tile skin and the set of owned skins (persisted). The active
/// id is a [ValueListenable] so the board re-skins live when the player applies
/// a new one.
class SkinService {
  SkinService(this._prefs);

  static const _activeKey = 'skin_active';
  static const _ownedKey = 'skin_owned';
  static const _defaultSkin = 'standart';

  final PreferencesService _prefs;

  final ValueNotifier<String> activeSkinId = ValueNotifier(_defaultSkin);

  void load() {
    activeSkinId.value = _prefs.getString(_activeKey) ?? _defaultSkin;
  }

  Set<String> get owned => {_defaultSkin, ..._prefs.getStringList(_ownedKey)};

  bool isOwned(String id) => owned.contains(id);
  bool isActive(String id) => activeSkinId.value == id;

  Future<void> own(String id) {
    final next = (owned..add(id)).toList();
    return _prefs.setStringList(_ownedKey, next);
  }

  Future<void> select(String id) {
    activeSkinId.value = id;
    return _prefs.setString(_activeKey, id);
  }

  void dispose() => activeSkinId.dispose();
}
