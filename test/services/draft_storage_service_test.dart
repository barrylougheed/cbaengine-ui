import 'package:app/models/persisted_draft.dart';
import 'package:app/services/draft_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DraftStorageService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service = DraftStorageService(await SharedPreferences.getInstance());
  });

  test('read returns null when nothing has been saved', () async {
    expect(await service.read(), isNull);
  });

  test('write then read round-trips the draft', () async {
    final draft = PersistedDraft(
      councilId: 'fingal-county-council',
      councilName: 'Fingal County Council',
      leaId: 'fingal-balbriggan',
      leaName: 'Balbriggan',
      topic: 'housing',
      subject: 'Subject',
      body: 'Body',
      savedAt: DateTime.utc(2026, 1, 1),
    );

    await service.write(draft);
    final read = await service.read();

    expect(read, draft);
  });

  test('clear removes the saved draft', () async {
    await service.write(PersistedDraft(savedAt: DateTime.utc(2026, 1, 1)));

    await service.clear();

    expect(await service.read(), isNull);
  });

  test('corrupt stored content is treated as no draft, not a crash', () async {
    SharedPreferences.setMockInitialValues({'cbaengine.draft.v1': 'not valid json'});
    service = DraftStorageService(await SharedPreferences.getInstance());

    expect(await service.read(), isNull);
  });
}
