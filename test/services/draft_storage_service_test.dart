import 'package:app/models/draft.dart';
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

  test('write then read round-trips a draft started from topics', () async {
    final draft = PersistedDraft(
      councilId: 'fingal-county-council',
      councilName: 'Fingal County Council',
      leaId: 'fingal-balbriggan',
      leaName: 'Balbriggan',
      topicIds: const ['housing-crisis', 'save-stephens-green'],
      templateVariants: const {'housing-crisis': 'v3', 'save-stephens-green': 'v1'},
      senderName: 'Sam Resident',
      subject: 'Subject',
      body: 'Body',
      savedAt: DateTime.utc(2026, 1, 1),
    );

    await service.write(draft);
    final read = await service.read();

    expect(read, draft);
    expect(read!.apiTopics, ['housing-crisis', 'save-stephens-green']);
  });

  test('a draft the resident wrote themselves is sent as the "custom" topic', () async {
    final draft = PersistedDraft(
      mode: ComposeMode.ownWords,
      leaId: 'fingal-balbriggan',
      senderName: 'Sam Resident',
      subject: 'Subject',
      body: 'Body',
      savedAt: DateTime.utc(2026, 1, 1),
    );

    await service.write(draft);

    final read = await service.read();
    expect(read!.mode, ComposeMode.ownWords);
    expect(read.apiTopics, ['custom']);
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

  test('a draft saved before topics and names existed (version 1) is ignored', () async {
    SharedPreferences.setMockInitialValues({
      'cbaengine.draft.v1':
          '{"version":1,"leaId":"fingal-balbriggan","topic":"housing","subject":"S","body":"B",'
          '"savedAt":"2026-01-01T00:00:00.000Z"}',
    });
    service = DraftStorageService(await SharedPreferences.getInstance());

    expect(await service.read(), isNull);
  });
}
