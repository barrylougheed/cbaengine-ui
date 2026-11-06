import 'dart:async';
import 'dart:convert';

import 'package:app/models/campaign_summary.dart';
import 'package:app/models/council.dart';
import 'package:app/models/councillor_preview.dart';
import 'package:app/models/draft.dart';
import 'package:app/models/lea.dart';
import 'package:app/models/message_intent.dart';
import 'package:app/models/persisted_draft.dart';
import 'package:app/models/topic_summary.dart';
import 'package:app/providers/core_providers.dart';
import 'package:app/providers/draft/draft_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The in-progress email, for each of its three kinds: issues (with ticked
/// proposals), the resident's own words, and a campaign. The server writes the
/// text for issues and campaigns; the notifier keeps what it composed, the
/// wording it chose, and whether the resident has since edited it.
void main() {
  const council = Council(id: 'fingal-county-council', name: 'Fingal County Council');
  const lea = Lea(
    id: 'fingal-balbriggan',
    name: 'Balbriggan',
    council: 'Fingal County Council',
    councillors: [CouncillorPreview(name: 'A Councillor', party: 'Independent')],
  );
  const housing = TopicSummary(
    id: 'housing-crisis',
    title: 'Housing Crisis',
    proposals: [
      ProposalSummary(id: 'housing-p1', text: 'a ban on bulk purchases'),
      ProposalSummary(id: 'housing-p2', text: 'a public register'),
      ProposalSummary(id: 'housing-p3', text: 'a third thing'),
    ],
  );
  const lock = TopicSummary(
    id: 'triple-lock',
    title: 'Triple Lock',
    proposals: [
      ProposalSummary(id: 'lock-p1', text: 'keeping the triple lock'),
      ProposalSummary(id: 'lock-p2', text: 'a review of it'),
    ],
  );
  const green = CampaignSummary(id: 'save-stephens-green', title: "Save Stephen's Green", summary: 'About the Green.');

  late ProviderContainer container;
  late List<Map<String, dynamic>> composeRequests;
  late List<Map<String, dynamic>> campaignRequests;
  late Future<http.Response> Function(Map<String, dynamic> request) composeAnswer;
  late Future<http.Response> Function(Map<String, dynamic> request) campaignAnswer;

  Draft state() => container.read(draftNotifierProvider);
  DraftNotifier notifier() => container.read(draftNotifierProvider.notifier);

  http.Response ok(Object body) =>
      http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

  /// What the server would answer for the issues asked: an opener "o2" for each
  /// (unless one was pinned) and subject "s2", with text built from them.
  Future<http.Response> defaultIssueAnswer(Map<String, dynamic> request) async {
    final asked = [for (final topic in request['topics'] as List) topic as Map<String, dynamic>];
    final pinned = Map<String, String>.from(request['variants'] as Map);
    final ids = [for (final topic in asked) topic['id'] as String];
    final variants = {for (final id in ids) id: pinned[id] ?? 'o2', '_subject': pinned['_subject'] ?? 's2'};
    final sections = [
      for (final topic in asked) '${topic['id']} (${variants[topic['id']]}): ${(topic['proposals'] as List).join(', ')}',
    ];
    return ok({
      'topics': ids,
      'variants': variants,
      'subject': 'Subject ${variants['_subject']}: ${ids.join(' and ')}',
      'body': sections.join('\n\n'),
      'footer': 'Started from a topic.',
    });
  }

  Future<http.Response> defaultCampaignAnswer(Map<String, dynamic> request) async {
    final pinned = Map<String, String>.from(request['variants'] as Map);
    final variant = pinned['save-stephens-green'] ?? 'v2';
    return ok({
      'topics': ['save-stephens-green'],
      'variants': {'save-stephens-green': variant},
      'subject': 'Campaign subject $variant',
      'body': 'Campaign body $variant.',
      'footer': "Sent as part of the 'Save Stephen's Green' campaign.",
    });
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    composeRequests = [];
    campaignRequests = [];
    composeAnswer = defaultIssueAnswer;
    campaignAnswer = defaultCampaignAnswer;
    final httpClient = MockClient((request) async {
      if (request.url.path == '/topics/compose') {
        final decoded = jsonDecode(request.body) as Map<String, dynamic>;
        composeRequests.add(decoded);
        return composeAnswer(decoded);
      }
      if (request.url.path == '/campaigns/save-stephens-green/compose') {
        final decoded = jsonDecode(request.body) as Map<String, dynamic>;
        campaignRequests.add(decoded);
        return campaignAnswer(decoded);
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

  test('starts empty, with issues as the kind of email', () {
    container.dispose();
    container = ProviderContainer.test(); // no council or area chosen yet

    expect(state(), const Draft());
    expect(state().intent, MessageIntent.issues);
    expect(state().isContentReady, isFalse);
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
    setUp(() => notifier().setIntent(MessageIntent.own));

    test('is ready once there is a name, a subject and a body', () {
      expect(state().isContentReady, isFalse);

      notifier().setSubject('Subject');
      expect(state().isContentReady, isFalse);
      notifier().setBody('Body');
      expect(state().isContentReady, isFalse); // still no name
      notifier().setSenderName('Sam Resident');
      expect(state().isContentReady, isTrue);
    });

    test('needs the area as well before it can be reviewed', () {
      notifier()
        ..setSubject('Subject')
        ..setBody('Body')
        ..setSenderName('Sam Resident');
      expect(state().isReadyToReview, isTrue);

      container.dispose();
      container = ProviderContainer.test();
      notifier()
        ..setIntent(MessageIntent.own)
        ..setSubject('Subject')
        ..setBody('Body')
        ..setSenderName('Sam Resident');

      expect(state().isContentReady, isTrue);
      expect(state().isReadyToReview, isFalse); // no area yet
    });

    test('is sent as the reserved "custom" topic, with no proposals or variants', () {
      expect(state().apiTopics, ['custom']);
      expect(state().proposalsInUse, isEmpty);
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

    test('typed text counts as edited, so changing the kind of email asks first', () {
      expect(state().hasEditedText, isFalse);

      notifier().setBody('Something I wrote');

      expect(state().hasEditedText, isTrue);
    });
  });

  group('choosing issues and ticking proposals', () {
    test('fills in the subject, body and footer the server composed, asking with no area', () async {
      final error = await notifier().chooseIssues([housing], {
        'housing-crisis': ['housing-p1', 'housing-p3'],
      });

      expect(error, isNull);
      expect(state().issues, [housing]);
      expect(state().subject, 'Subject s2: housing-crisis');
      expect(state().body, 'housing-crisis (o2): housing-p1, housing-p3');
      expect(state().footer, 'Started from a topic.');
      expect(state().composedBody, state().body);
      expect(composeRequests.single, {
        'topics': [
          {
            'id': 'housing-crisis',
            'proposals': ['housing-p1', 'housing-p3'],
          },
        ],
        'variants': <String, String>{},
      });
    });

    test('an issue with nothing ticked yet has no text: every chosen issue needs a tick', () async {
      final error = await notifier().chooseIssues([housing, lock], {
        'housing-crisis': ['housing-p1'],
        'triple-lock': <String>[],
      });

      expect(error, isNull);
      expect(composeRequests, isEmpty); // nothing to ask the server for yet
      expect(state().issues, [housing, lock]);
      expect(state().ticked, {
        'housing-crisis': ['housing-p1'],
        'triple-lock': <String>[],
      });
      expect(state().selectionComplete, isFalse);
      expect(state().subject, isEmpty);
      expect(state().footer, isNull);
      expect(state().isContentReady, isFalse);
    });

    test('is ready once every issue has a tick and there is a name', () async {
      await notifier().chooseIssues([housing, lock], {
        'housing-crisis': ['housing-p1'],
        'triple-lock': ['lock-p2'],
      });
      expect(state().selectionComplete, isTrue);
      expect(state().isContentReady, isFalse); // no name yet

      notifier().setSenderName('Sam Resident');

      expect(state().isContentReady, isTrue);
      expect(state().isReadyToReview, isTrue);
    });

    test('sends the chosen issues, their ticks and the wording of those issues only', () async {
      await notifier().chooseIssues([housing, lock], {
        'housing-crisis': ['housing-p1'],
        'triple-lock': ['lock-p1', 'lock-p2'],
      });
      await notifier().chooseIssues([lock], {
        'triple-lock': ['lock-p1', 'lock-p2'],
      }); // housing is un-ticked: its wording is remembered but not sent

      expect(state().apiTopics, ['triple-lock']);
      expect(state().proposalsInUse, {
        'triple-lock': ['lock-p1', 'lock-p2'],
      });
      expect(state().variantsInUse, {'triple-lock': 'o2', '_subject': 's2'});
    });

    test('keeps the wording already shown when the ticks change', () async {
      await notifier().chooseIssues([housing], {
        'housing-crisis': ['housing-p1'],
      });
      composeAnswer = (request) async {
        final pinned = Map<String, String>.from(request['variants'] as Map);
        final ids = [for (final topic in request['topics'] as List) (topic as Map<String, dynamic>)['id'] as String];
        return ok({
          'topics': ids,
          'variants': {for (final id in ids) id: pinned[id] ?? 'o5', '_subject': pinned['_subject'] ?? 's5'},
          'subject': 'S',
          'body': 'B',
          'footer': 'F',
        });
      };

      await notifier().chooseIssues([housing], {
        'housing-crisis': ['housing-p1', 'housing-p2'],
      });

      // The second request pinned what the first one returned.
      expect(composeRequests.last['variants'], {'housing-crisis': 'o2', '_subject': 's2'});
      expect(state().templateVariants['housing-crisis'], 'o2');
      expect(state().templateVariants['_subject'], 's2');
    });

    test('remembers the opener of an issue that was un-ticked, so ticking it again does not re-roll it', () async {
      await notifier().chooseIssues([housing, lock], {
        'housing-crisis': ['housing-p1'],
        'triple-lock': ['lock-p1'],
      });
      await notifier().chooseIssues([lock], {
        'triple-lock': ['lock-p1'],
      });

      await notifier().chooseIssues([housing, lock], {
        'housing-crisis': ['housing-p1'],
        'triple-lock': ['lock-p1'],
      });

      expect(composeRequests.last['variants'], containsPair('housing-crisis', 'o2'));
    });

    test('replaces any edits the resident made', () async {
      await notifier().chooseIssues([housing], {
        'housing-crisis': ['housing-p1'],
      });
      notifier().setBody('My own words instead');
      expect(state().hasEditedText, isTrue);

      await notifier().chooseIssues([housing], {
        'housing-crisis': ['housing-p1', 'housing-p2'],
      });

      expect(state().body, contains('housing-p2'));
      expect(state().hasEditedText, isFalse);
    });

    test('un-ticking every proposal clears the text and the footer but keeps the issue chosen', () async {
      await notifier().chooseIssues([housing], {
        'housing-crisis': ['housing-p1'],
      });

      await notifier().chooseIssues([housing], {'housing-crisis': <String>[]});

      expect(state().issues, [housing]);
      expect((state().subject, state().body, state().footer), ('', '', null));
    });

    test('un-choosing every issue empties the selection and the text', () async {
      await notifier().chooseIssues([housing], {
        'housing-crisis': ['housing-p1'],
      });

      await notifier().chooseIssues([], {});

      expect(state().issues, isEmpty);
      expect(state().ticked, isEmpty);
      expect((state().subject, state().body, state().footer), ('', '', null));
    });

    test('the screen is told to refill its text fields each time the text is replaced', () async {
      final before = state().revision;

      await notifier().chooseIssues([housing], {
        'housing-crisis': ['housing-p1'],
      });
      final afterFirst = state().revision;
      await notifier().chooseIssues([housing], {'housing-crisis': <String>[]});

      expect(afterFirst, greaterThan(before));
      expect(state().revision, greaterThan(afterFirst));
    });

    test('a slow answer to an earlier choice never overwrites a later one', () async {
      final slow = Completer<http.Response>();
      var call = 0;
      composeAnswer = (request) {
        call++;
        return call == 1 ? slow.future : defaultIssueAnswer(request);
      };

      final first = notifier().chooseIssues([housing], {
        'housing-crisis': ['housing-p1'],
      });
      await notifier().chooseIssues([lock], {
        'triple-lock': ['lock-p1'],
      });
      slow.complete(await defaultIssueAnswer(composeRequests.first));
      await first;

      expect(state().issues, [lock]);
      expect(state().subject, contains('triple-lock'));
    });

    test('with no connection, says so and leaves the draft as it was', () async {
      composeAnswer = (_) async => throw http.ClientException('offline');

      final error = await notifier().chooseIssues([housing], {
        'housing-crisis': ['housing-p1'],
      });

      expect(error, contains('check your connection'));
      expect(state().subject, isEmpty);
    });

    test("passes on the server's own message, e.g. when too many issues were chosen", () async {
      composeAnswer = (_) async => http.Response(
        jsonEncode({'detail': 'Too many topics for one email. Please choose fewer.'}),
        422,
        headers: {'content-type': 'application/json'},
      );

      final error = await notifier().chooseIssues([housing], {
        'housing-crisis': ['housing-p1'],
      });

      expect(error, 'Too many topics for one email. Please choose fewer.');
    });
  });

  group('backing a campaign', () {
    setUp(() => notifier().setIntent(MessageIntent.campaign));

    test('fills in the subject, body and footer the server composed for the campaign', () async {
      final error = await notifier().chooseCampaign(green);

      expect(error, isNull);
      expect(state().campaign, green);
      expect(state().subject, 'Campaign subject v2');
      expect(state().body, 'Campaign body v2.');
      expect(state().footer, contains("Save Stephen's Green"));
      expect(state().composedBody, state().body);
      expect(campaignRequests.single, {'variants': <String, String>{}});
    });

    test('is sent as the campaign id with the variant shown, and no proposals', () async {
      await notifier().chooseCampaign(green);

      expect(state().apiTopics, ['save-stephens-green']);
      expect(state().variantsInUse, {'save-stephens-green': 'v2'});
      expect(state().proposalsInUse, isEmpty);
    });

    test('is ready once there is a name', () async {
      await notifier().chooseCampaign(green);
      expect(state().isContentReady, isFalse);

      notifier().setSenderName('Sam Resident');

      expect(state().isContentReady, isTrue);
      expect(state().isReadyToReview, isTrue);
    });

    test('is not ready with no campaign chosen, however much text there is', () {
      notifier()
        ..setSubject('Subject')
        ..setBody('Body')
        ..setSenderName('Sam Resident');

      expect(state().isContentReady, isFalse);
    });

    test('choosing the same campaign again keeps the variant the resident was shown', () async {
      await notifier().chooseCampaign(green);
      campaignAnswer = (request) async {
        final pinned = Map<String, String>.from(request['variants'] as Map);
        return ok({
          'topics': ['save-stephens-green'],
          'variants': {'save-stephens-green': pinned['save-stephens-green'] ?? 'v5'},
          'subject': 'S',
          'body': 'B',
          'footer': 'F',
        });
      };

      await notifier().chooseCampaign(green);

      expect(campaignRequests.last['variants'], {'save-stephens-green': 'v2'});
      expect(state().variantsInUse, {'save-stephens-green': 'v2'});
    });

    test('typed changes count as edits', () async {
      await notifier().chooseCampaign(green);
      expect(state().hasEditedText, isFalse);

      notifier().setBody('${state().body} And more.');

      expect(state().hasEditedText, isTrue);
    });

    test('with no connection, says so and leaves the draft as it was', () async {
      campaignAnswer = (_) async => throw http.ClientException('offline');

      final error = await notifier().chooseCampaign(green);

      expect(error, contains('check your connection'));
      expect(state().campaign, isNull);
      expect(state().subject, isEmpty);
    });

    test('a slow answer for an earlier campaign choice is ignored after the kind of email changed', () async {
      final slow = Completer<http.Response>();
      campaignAnswer = (_) => slow.future;

      final pending = notifier().chooseCampaign(green);
      notifier().setIntent(MessageIntent.own);
      slow.complete(await defaultCampaignAnswer({'variants': <String, String>{}}));
      await pending;

      expect(state().campaign, isNull);
      expect(state().intent, MessageIntent.own);
    });
  });

  group('switching between the kinds of email', () {
    test('clears the issues, ticks, campaign, text and footer', () async {
      await notifier().chooseIssues([housing], {
        'housing-crisis': ['housing-p1'],
      });

      notifier().setIntent(MessageIntent.own);

      expect(state().intent, MessageIntent.own);
      expect(state().issues, isEmpty);
      expect(state().ticked, isEmpty);
      expect(state().campaign, isNull);
      expect((state().subject, state().body, state().footer), ('', '', null));
    });

    test('keeps the name the resident typed, and the council and area', () async {
      notifier().setSenderName('Sam Resident');

      notifier().setIntent(MessageIntent.campaign);

      expect(state().senderName, 'Sam Resident');
      expect(state().lea, lea);
    });

    test('choosing the kind of email already chosen changes nothing', () async {
      await notifier().chooseIssues([housing], {
        'housing-crisis': ['housing-p1'],
      });
      final before = state();

      notifier().setIntent(MessageIntent.issues);

      expect(state(), before);
    });

    test('an answer still on its way for the old kind of email is ignored', () async {
      final slow = Completer<http.Response>();
      composeAnswer = (_) => slow.future;

      final pending = notifier().chooseIssues([housing], {
        'housing-crisis': ['housing-p1'],
      });
      notifier().setIntent(MessageIntent.own);
      slow.complete(
        await defaultIssueAnswer({
          'topics': [
            {
              'id': 'housing-crisis',
              'proposals': ['housing-p1'],
            },
          ],
          'variants': <String, String>{},
        }),
      );
      await pending;

      expect(state().issues, isEmpty);
      expect(state().subject, isEmpty);
    });
  });

  test('selectTestRecipient sets a debug LEA with id manual-test-recipient', () {
    notifier().selectTestRecipient();

    expect(state().lea?.id, 'manual-test-recipient');
    expect(state().lea?.councillors, isNotEmpty);
  });

  test('clear resets to an empty draft', () async {
    await notifier().chooseIssues([housing], {
      'housing-crisis': ['housing-p1'],
    });
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
