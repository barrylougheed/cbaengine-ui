import 'dart:async';
import 'dart:convert';

import 'package:app/models/council.dart';
import 'package:app/models/councillor_preview.dart';
import 'package:app/models/draft.dart';
import 'package:app/models/lea.dart';
import 'package:app/models/persisted_draft.dart';
import 'package:app/models/topic_summary.dart';
import 'package:app/providers/core_providers.dart';
import 'package:app/providers/draft/draft_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const council = Council(id: 'fingal-county-council', name: 'Fingal County Council');
  const lea = Lea(
    id: 'fingal-balbriggan',
    name: 'Balbriggan',
    council: 'Fingal County Council',
    councillors: [CouncillorPreview(name: 'A Councillor', party: 'Independent')],
  );
  const housing = TopicSummary(id: 'housing-crisis', title: 'Housing Crisis');
  const green = TopicSummary(id: 'save-stephens-green', title: "Save Stephen's Green");

  late ProviderContainer container;
  late List<Map<String, dynamic>> composeRequests;
  late Future<http.Response> Function(Map<String, dynamic> request) composeAnswer;

  Draft state() => container.read(draftNotifierProvider);
  DraftNotifier notifier() => container.read(draftNotifierProvider.notifier);

  /// What the server would answer for the topics asked: a variant for each
  /// (v2 unless one was pinned), with the text built from the variant ids.
  Future<http.Response> defaultAnswer(Map<String, dynamic> request) async {
    final topics = List<String>.from(request['topics'] as List);
    final pinned = Map<String, String>.from(request['variants'] as Map);
    final variants = {for (final id in topics) id: pinned[id] ?? 'v2'};
    final body = topics.length == 1
        ? 'Body of ${topics.single} (${variants[topics.single]})'
        : topics.map((id) => '$id\nBody of $id (${variants[id]})').join('\n\n');
    return http.Response(
      jsonEncode({
        'topics': topics,
        'variants': variants,
        'subject': topics.length == 1 ? 'Subject of ${topics.single}' : 'Your stance on ${topics.join(' and ')}',
        'body': body,
        'footer': 'Started from a topic.',
      }),
      200,
      headers: {'content-type': 'application/json'},
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    composeRequests = [];
    composeAnswer = defaultAnswer;
    final httpClient = MockClient((request) async {
      if (request.url.path == '/topics/compose') {
        final decoded = jsonDecode(request.body) as Map<String, dynamic>;
        composeRequests.add(decoded);
        return composeAnswer(decoded);
      }
      return http.Response('{}', 404);
    });
    container = ProviderContainer.test(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs), httpClientProvider.overrideWithValue(httpClient)],
    );
    notifier()
      ..selectCouncil(council)
      ..selectLea(lea);
  });

  test('starts empty, in topics mode', () {
    container.dispose();
    container = ProviderContainer.test(); // no council or area chosen yet

    expect(state(), const Draft());
    expect(state().mode, ComposeMode.topics);
    expect(state().isReadyToReview, isFalse);
  });

  test('selecting a different council clears any already-selected LEA', () {
    notifier().selectCouncil(const Council(id: 'dublin-city-council', name: 'Dublin City Council'));

    expect(state().lea, isNull);
  });

  test('selectLea sets the LEA', () {
    expect(state().lea, lea);
  });

  test('setSubject, setBody and setSenderName update their fields independently', () {
    notifier()
      ..setSubject('Subject')
      ..setBody('Body')
      ..setSenderName('Sam Resident');

    expect((state().subject, state().body, state().senderName), ('Subject', 'Body', 'Sam Resident'));
  });

  group('writing your own', () {
    setUp(() => notifier().setMode(ComposeMode.ownWords));

    test('is ready once there is a name, a subject and a body', () {
      expect(state().isReadyToReview, isFalse);

      notifier().setSubject('Subject');
      expect(state().isReadyToReview, isFalse);
      notifier().setBody('Body');
      expect(state().isReadyToReview, isFalse); // still no name
      notifier().setSenderName('Sam Resident');
      expect(state().isReadyToReview, isTrue);
    });

    test('is sent as the reserved "custom" topic, with no variants', () {
      expect(state().apiTopics, ['custom']);
      expect(state().variantsInUse, isEmpty);
    });

    test('whitespace-only subject, body or name does not count', () {
      notifier()
        ..setSubject('   ')
        ..setBody('   ')
        ..setSenderName('   ');

      expect(state().isReadyToReview, isFalse);
    });

    test('a name that is too long, or has a line break, does not count', () {
      notifier()
        ..setSubject('Subject')
        ..setBody('Body');

      notifier().setSenderName('x' * (maxSenderNameLength + 1));
      expect(state().isReadyToReview, isFalse);

      notifier().setSenderName('Sam\nResident');
      expect(state().isReadyToReview, isFalse);

      notifier().setSenderName('x' * maxSenderNameLength);
      expect(state().isReadyToReview, isTrue);
    });

    test('unfinished text in double square brackets blocks the review', () {
      notifier()
        ..setSenderName('Sam Resident')
        ..setSubject('Subject')
        ..setBody('Body');
      expect(state().isReadyToReview, isTrue);

      notifier().setBody('Body [[context: fill me in]]');

      expect(state().hasUnfinishedText, isTrue);
      expect(state().isReadyToReview, isFalse);
    });

    test('typed text counts as edited, so changing mode asks first', () {
      expect(state().hasEditedText, isFalse);

      notifier().setBody('Something I wrote');

      expect(state().hasEditedText, isTrue);
    });
  });

  group('choosing topics', () {
    test('fills in the subject, body and footer the server composed for them', () async {
      final error = await notifier().chooseTopics([housing]);

      expect(error, isNull);
      expect(state().topics, [housing]);
      expect(state().subject, 'Subject of housing-crisis');
      expect(state().body, 'Body of housing-crisis (v2)');
      expect(state().footer, 'Started from a topic.');
      expect(composeRequests.single, {
        'local_electoral_area': 'fingal-balbriggan',
        'topics': ['housing-crisis'],
        'variants': <String, String>{},
      });
    });

    test('is ready to review once a name is added, with the variants of the chosen topics', () async {
      await notifier().chooseTopics([housing, green]);
      expect(state().isReadyToReview, isFalse); // no name yet

      notifier().setSenderName('Sam Resident');

      expect(state().isReadyToReview, isTrue);
      expect(state().apiTopics, ['housing-crisis', 'save-stephens-green']);
      expect(state().variantsInUse, {'housing-crisis': 'v2', 'save-stephens-green': 'v2'});
    });

    test('keeps the variant already shown for a topic when the selection changes', () async {
      composeAnswer = (request) async {
        final response = await defaultAnswer(request);
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        // The server rolls v5 for any topic that has no pinned variant.
        final variants = {
          for (final id in List<String>.from(decoded['topics'] as List))
            id: Map<String, String>.from(request['variants'] as Map)[id] ?? 'v5',
        };
        return http.Response(jsonEncode({...decoded, 'variants': variants}), 200);
      };
      await notifier().chooseTopics([housing]);
      composeAnswer = defaultAnswer;

      await notifier().chooseTopics([housing, green]);

      // The second request pinned what the first one returned.
      expect(composeRequests.last['variants'], {'housing-crisis': 'v5'});
    });

    test('remembers a topic that was un-ticked, so ticking it again does not re-roll it', () async {
      await notifier().chooseTopics([housing, green]);
      await notifier().chooseTopics([housing]);

      await notifier().chooseTopics([housing, green]);

      expect(composeRequests.last['variants'], {'housing-crisis': 'v2', 'save-stephens-green': 'v2'});
      // ...but only the topics in use are sent when the message is drafted.
      await notifier().chooseTopics([housing]);
      expect(state().variantsInUse.keys, ['housing-crisis']);
    });

    test('replaces any edits the resident made', () async {
      await notifier().chooseTopics([housing]);
      notifier().setBody('My own edit');
      expect(state().hasEditedText, isTrue);

      await notifier().chooseTopics([housing, green]);

      expect(state().body, startsWith('housing-crisis\n'));
      expect(state().hasEditedText, isFalse);
    });

    test('un-ticking every topic clears the text and the footer', () async {
      await notifier().chooseTopics([housing]);

      await notifier().chooseTopics([]);

      expect(state().topics, isEmpty);
      expect(state().subject, '');
      expect(state().body, '');
      expect(state().footer, isNull);
      expect(composeRequests, hasLength(1)); // nothing to ask the server for
    });

    test('the screen is told to refill its text fields each time the text is replaced', () async {
      final before = state().revision;

      await notifier().chooseTopics([housing]);
      final afterCompose = state().revision;
      await notifier().chooseTopics([]);

      expect(afterCompose, greaterThan(before));
      expect(state().revision, greaterThan(afterCompose));
    });

    test('a slow answer to an earlier choice never overwrites a later one', () async {
      final slowFirst = Completer<http.Response>();
      var calls = 0;
      composeAnswer = (request) {
        calls++;
        return calls == 1 ? slowFirst.future : defaultAnswer(request);
      };

      final first = notifier().chooseTopics([housing]);
      await notifier().chooseTopics([housing, green]);
      slowFirst.complete(await defaultAnswer({'topics': ['housing-crisis'], 'variants': <String, String>{}}));
      await first;

      expect(state().topics, [housing, green]);
    });

    test('with no connection, says so and leaves the draft as it was', () async {
      await notifier().chooseTopics([housing]);
      final before = state();
      composeAnswer = (_) => throw http.ClientException('offline');

      final error = await notifier().chooseTopics([housing, green]);

      expect(error, contains('check your connection'));
      expect(state(), before);
    });

    test("passes on the server's own message, e.g. when too many topics were chosen", () async {
      composeAnswer = (_) async => http.Response(
        jsonEncode({'detail': 'Too many topics for one email. Please choose fewer.'}),
        422,
        headers: {'content-type': 'application/json'},
      );

      final error = await notifier().chooseTopics([housing, green]);

      expect(error, 'Too many topics for one email. Please choose fewer.');
    });
  });

  group('switching between topics and writing your own', () {
    test('clears the topics, the text and the footer', () async {
      await notifier().chooseTopics([housing]);

      notifier().setMode(ComposeMode.ownWords);

      expect(state().mode, ComposeMode.ownWords);
      expect(state().topics, isEmpty);
      expect(state().subject, '');
      expect(state().body, '');
      expect(state().footer, isNull);
    });

    test('keeps the name the resident typed', () async {
      notifier().setSenderName('Sam Resident');

      notifier().setMode(ComposeMode.ownWords);

      expect(state().senderName, 'Sam Resident');
    });

    test('an answer still on its way for the old mode is ignored', () async {
      final slow = Completer<http.Response>();
      composeAnswer = (_) => slow.future;
      final pending = notifier().chooseTopics([housing]);

      notifier().setMode(ComposeMode.ownWords);
      slow.complete(await defaultAnswer({'topics': ['housing-crisis'], 'variants': <String, String>{}}));
      await pending;

      expect(state().mode, ComposeMode.ownWords);
      expect(state().subject, '');
    });
  });

  test('selectTestRecipient sets a debug LEA with id manual-test-recipient', () {
    notifier().selectTestRecipient();

    expect(state().lea?.id, 'manual-test-recipient');
    expect(state().lea?.councillors, isNotEmpty);
  });

  test('clear resets to an empty draft', () async {
    await notifier().chooseTopics([housing]);
    notifier().setSenderName('Sam Resident');

    notifier().clear();

    expect(state(), const Draft());
  });

  test('clear also wipes the draft saved in browser storage', () async {
    // Otherwise a draft abandoned mid-connect stays saved indefinitely.
    final storage = container.read(draftStorageServiceProvider);
    await storage.write(PersistedDraft(subject: 'Subject', savedAt: DateTime.utc(2026, 1, 1)));

    notifier().clear();
    await pumpEventQueue(); // the wipe isn't awaited by clear()

    expect(await storage.read(), isNull);
  });
}
