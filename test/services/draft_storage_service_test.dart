import 'package:app/models/message_intent.dart';
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

  test('write then read round-trips an email about issues, with the wording shown', () async {
    final draft = PersistedDraft(
      councilId: 'fingal-county-council',
      councilName: 'Fingal County Council',
      leaId: 'fingal-balbriggan',
      leaName: 'Balbriggan',
      intent: MessageIntent.issues,
      topicIds: const ['housing-crisis', 'triple-lock'],
      templateVariants: const {
        '_intro': 'open-conversation',
        'housing-crisis': 'where-you-stand',
        'triple-lock': 'real-solutions',
        '_subject': 'stand',
      },
      senderName: 'Sam Resident',
      subject: 'Subject',
      body: 'Body',
      savedAt: DateTime.utc(2026, 1, 1),
    );

    await service.write(draft);
    final read = await service.read();

    expect(read, draft);
    expect(read!.apiTopics, ['housing-crisis', 'triple-lock']);
    expect(read.templateVariants['triple-lock'], 'real-solutions');
    expect(read.toJson().containsKey('proposals'), isFalse); // issues have nothing to tick
  });

  test('a draft the resident wrote themselves is sent as the "custom" topic', () async {
    final draft = PersistedDraft(
      intent: MessageIntent.own,
      leaId: 'fingal-balbriggan',
      senderName: 'Sam Resident',
      subject: 'Subject',
      body: 'Body',
      savedAt: DateTime.utc(2026, 1, 1),
    );

    await service.write(draft);

    final read = await service.read();
    expect(read!.intent, MessageIntent.own);
    expect(read.apiTopics, ['custom']);
    expect(read.templateVariants, isEmpty);
  });

  test('a campaign draft is sent as the campaign id with the variant shown', () async {
    final draft = PersistedDraft(
      intent: MessageIntent.campaign,
      leaId: 'fingal-balbriggan',
      topicIds: const ['save-stephens-green'],
      templateVariants: const {'save-stephens-green': 'v2'},
      senderName: 'Sam Resident',
      subject: 'Subject',
      body: 'Body',
      savedAt: DateTime.utc(2026, 1, 1),
    );

    await service.write(draft);

    final read = await service.read();
    expect(read!.intent, MessageIntent.campaign);
    expect(read.apiTopics, ['save-stephens-green']);
    expect(read.templateVariants, {'save-stephens-green': 'v2'});
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

  test('a draft saved before proposals and campaigns existed (version 2) is ignored', () async {
    SharedPreferences.setMockInitialValues({
      'cbaengine.draft.v1':
          '{"version":2,"leaId":"fingal-balbriggan","mode":"topics","topicIds":["housing-crisis"],'
          '"templateVariants":{"housing-crisis":"v1"},"senderName":"Sam","subject":"S","body":"B",'
          '"savedAt":"2026-01-01T00:00:00.000Z"}',
    });
    service = DraftStorageService(await SharedPreferences.getInstance());

    expect(await service.read(), isNull);
  });

  test('a draft saved while issues still had proposals (version 3) is ignored, as its wording ids are gone', () async {
    SharedPreferences.setMockInitialValues({
      'cbaengine.draft.v1':
          '{"version":3,"leaId":"fingal-balbriggan","intent":"issues","topicIds":["housing-crisis"],'
          '"proposals":{"housing-crisis":["public-register-of-house-bidding"]},'
          '"templateVariants":{"housing-crisis":"doing","_subject":"stand","_intro":"open-conversation"},'
          '"senderName":"Sam","subject":"S","body":"B","savedAt":"2026-01-01T00:00:00.000Z"}',
    });
    service = DraftStorageService(await SharedPreferences.getInstance());

    expect(await service.read(), isNull);
  });
}
