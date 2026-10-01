import 'package:app/models/council.dart';
import 'package:app/models/councillor_preview.dart';
import 'package:app/models/draft.dart';
import 'package:app/models/lea.dart';
import 'package:app/models/persisted_draft.dart';
import 'package:app/providers/core_providers.dart';
import 'package:app/providers/draft/draft_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const council = Council(id: 'fingal-county-council', name: 'Fingal County Council');
  const lea = Lea(
    id: 'fingal-balbriggan',
    name: 'Balbriggan',
    council: 'Fingal County Council',
    councillors: [CouncillorPreview(name: 'A Councillor', party: 'Independent')],
  );

  late ProviderContainer container;
  Draft state() => container.read(draftNotifierProvider);
  DraftNotifier notifier() => container.read(draftNotifierProvider.notifier);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer.test(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
  });

  test('starts empty', () {
    expect(state(), const Draft());
    expect(state().isReadyToReview, isFalse);
  });

  test('selectCouncil sets the council', () {
    notifier().selectCouncil(council);

    expect(state().council, council);
  });

  test('selecting a different council clears any already-selected LEA', () {
    notifier().selectCouncil(council);
    notifier().selectLea(lea);

    notifier().selectCouncil(const Council(id: 'dublin-city-council', name: 'Dublin City Council'));

    expect(state().lea, isNull);
  });

  test('selectLea sets the LEA', () {
    notifier().selectCouncil(council);

    notifier().selectLea(lea);

    expect(state().lea, lea);
  });

  test('setTopic/setSubject/setBody update their fields independently', () {
    notifier().setTopic('housing');
    notifier().setSubject('Subject');
    notifier().setBody('Body');

    expect(state().topic, 'housing');
    expect(state().subject, 'Subject');
    expect(state().body, 'Body');
  });

  test('isReadyToReview is false until LEA, topic, subject and body are all set', () {
    notifier().selectCouncil(council);
    expect(state().isReadyToReview, isFalse);

    notifier().selectLea(lea);
    expect(state().isReadyToReview, isFalse);

    notifier().setTopic('housing');
    expect(state().isReadyToReview, isFalse);

    notifier().setSubject('Subject');
    expect(state().isReadyToReview, isFalse);

    notifier().setBody('Body');
    expect(state().isReadyToReview, isTrue);
  });

  test('isReadyToReview is false for whitespace-only subject/body', () {
    notifier().selectCouncil(council);
    notifier().selectLea(lea);
    notifier().setTopic('housing');
    notifier().setSubject('   ');
    notifier().setBody('   ');

    expect(state().isReadyToReview, isFalse);
  });

  test('selectTestRecipient sets a debug LEA with id manual-test-recipient', () {
    notifier().selectTestRecipient();

    expect(state().lea?.id, 'manual-test-recipient');
    expect(state().lea?.councillors, isNotEmpty);
  });

  test('clear resets to an empty draft', () {
    notifier().selectCouncil(council);
    notifier().selectLea(lea);
    notifier().setTopic('housing');
    notifier().setSubject('Subject');
    notifier().setBody('Body');

    notifier().clear();

    expect(state(), const Draft());
  });

  test('clear also wipes the draft saved in browser storage', () async {
    // Otherwise a draft abandoned mid-connect stays saved indefinitely.
    final storage = container.read(draftStorageServiceProvider);
    await storage.write(PersistedDraft(subject: 'Subject', savedAt: DateTime.utc(2026, 1, 1)));

    notifier().clear();
    await Future<void>.delayed(Duration.zero); // the wipe isn't awaited by clear()

    expect(await storage.read(), isNull);
  });
}
