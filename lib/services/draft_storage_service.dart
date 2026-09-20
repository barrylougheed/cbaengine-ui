import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/persisted_draft.dart';

class DraftStorageService {
  DraftStorageService(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'cbaengine.draft.v1';

  Future<PersistedDraft?> read() async {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      return PersistedDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> write(PersistedDraft draft) => _prefs.setString(_key, jsonEncode(draft.toJson()));

  Future<void> clear() => _prefs.remove(_key);
}
