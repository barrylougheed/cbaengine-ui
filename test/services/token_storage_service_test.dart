import 'package:app/models/stored_session.dart';
import 'package:app/services/key_value_store.dart';
import 'package:app/services/token_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}

void main() {
  late _InMemoryKeyValueStore store;
  late TokenStorageService service;

  setUp(() {
    store = _InMemoryKeyValueStore();
    service = TokenStorageService(store);
  });

  test('read returns null when nothing has been written', () async {
    expect(await service.read(), isNull);
  });

  test('write then read round-trips the session', () async {
    final session = StoredSession(
      token: 'the-token',
      email: 'resident@example.com',
      provider: 'google',
      connectedAt: DateTime.utc(2026, 1, 1),
    );

    await service.write(session);
    final read = await service.read();

    expect(read, session);
  });

  test('clear removes the stored session', () async {
    await service.write(
      StoredSession(
        token: 'the-token',
        email: 'resident@example.com',
        provider: 'google',
        connectedAt: DateTime.utc(2026, 1, 1),
      ),
    );

    await service.clear();

    expect(await service.read(), isNull);
  });

  test('corrupt stored content is treated as no session, not a crash', () async {
    await store.write('cbaengine.session.v1', 'not valid json');

    expect(await service.read(), isNull);
  });
}
