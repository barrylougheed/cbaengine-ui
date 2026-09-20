import 'dart:convert';

import '../models/stored_session.dart';
import 'key_value_store.dart';

class TokenStorageService {
  TokenStorageService(this._store);

  final KeyValueStore _store;
  static const _key = 'cbaengine.session.v1';

  Future<StoredSession?> read() async {
    final raw = await _store.read(_key);
    if (raw == null) return null;
    try {
      return StoredSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt/unexpected content on disk must never crash the boot
      // sequence — treat it the same as "not connected".
      return null;
    }
  }

  Future<void> write(StoredSession session) => _store.write(_key, jsonEncode(session.toJson()));

  Future<void> clear() => _store.delete(_key);
}
