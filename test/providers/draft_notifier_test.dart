import 'dart:async';
import 'dart:convert';

import 'package:app/models/campaign_summary.dart';
import 'package:app/models/council.dart';
import 'package:app/models/councillor_preview.dart';
import 'package:app/models/draft.dart';
import 'package:app/models/lea.dart';
import 'package:app/models/message_intent.dart';
import 'package:app/models/persisted_draft.dart';
import 'package:app/models/style_summary.dart';
import 'package:app/models/topic_summary.dart';
import 'package:app/providers/core_providers.dart';
import 'package:app/providers/draft/draft_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The in-progress email, for each of its three kinds: issues (chosen from the
/// list, then written in a letter style), the resident's own words, and a
/// campaign. The server writes the text for issues and campaigns; the notifier
/// keeps what it composed, the wording it chose, and whether the resident has
/// since edited it.
void main() {
  const council = Council(id: 'fingal-county-council', name: 'Fingal County Council');
  const lea = Lea(
    id: 'fingal-balbriggan',
    name: 'Balbriggan',
    council: 'Fingal County Council',
    councillors: [CouncillorPreview(name: 'A Councillor', party: 'Independent')],
  );
  const housing = TopicSummary(id: 'housing-crisis', title: 'Housing Crisis', category: 'housing');
  const lock = TopicSummary(id: 'triple-lock', title: 'Triple Lock', category: 'geopolitics');
  const formal = StyleSummary(id: 'formal-direct', title: 'Formal & Direct', description: 'Respectful.');
  const passionate = StyleSummary(id: 'passionate-urgent', title: 'Passionate & Urgent', description: 'Urgent.');
  const green = CampaignSummary(id: 'save-stephens-green', title: "Save Stephen's Green", summary: 'About the Green.');

  late ProviderContainer container;
  late List<Map<String, dynamic>> composeRequests;
  late List<Map<String, dynamic>> campaignRequests;
  late Future<http.Response> Function(Map<String, dynamic> request) composeAnswer;
  late Future<http.Response> Function(Map<String, dynamic> request) campaignAnswer;

  Draft state() => container.read(draftNotifierProvider);
  DraftNotifier notifier() => container.read(draftNotifierProvider.notifier);

  /// What a resident does: choose the issues, then a style, which writes the text.
  /// With no issues there is nothing to write.
  Future<String?> composeIssues(List<TopicSummary> chosen, [StyleSummary style = formal]) async {
    notifier().setIssues(chosen);
    if (chosen.isEmpty) return null;
    return notifier().chooseStyle(style);
  }

  http.Response ok(Object body) =>
      http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'});

  /// What the server would answer for the issues asked: an introduction "i2",
  /// a wording "w2" for each issue and subject "s2" (unless pinned), with text
  /// built from them.
  Future<http.Response> defaultIssueAnswer(Map<String, dynamic> request) async {
    final ids = [for (final id in request['topics'] as List) id as String];
    final pinned = Map<String, String>.from(request['variants'] as Map);
    final variants = {
      '_intro': pinned['_intro'] ?? 'i2',
      for (final id in ids) id: pinned[id] ?? 'w2',
      '_subject': pinned['_subject'] ?? 's2',
    };
    final sections = [for (final id in ids) '$id (${variants[id]})'];
    return ok({
      'topics': ids,
      'variants': variants,
      'style': request['style'] ?? 'formal-direct',
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

    test('typed text counts as edited, so changing the kind of email asks first', () {
      expect(state().hasEditedText, isFalse);

      notifier().setBody('Something I wrote');

      expect(state().hasEditedText, isTrue);
    });
  });

  group('choosing issues and a style', () {
    test('fills in the subject, body and footer the server composed, asking with no area', () async {
      final error = await composeIssues([housing]);

      expect(error, isNull);
      expect(state().issues, [housing]);
      expect(state().subject, 'Subject s2: housing-crisis');
      expect(state().body, 'housing-crisis (w2)');
      expect(state().footer, 'Started from a topic.');
      expect(state().composedBody, state().body);
      // The issue ids and the style are sent, and nothing else: there is no area.
      expect(composeRequests.single, {
        'topics': ['housing-crisis'],
        'style': 'formal-direct',
        'variants': <String, String>{},
      });
    });

    test('the issues and a style are the whole choice: once both are chosen there is text', () async {
      await composeIssues([housing, lock]);

      expect(state().issues, [housing, lock]);
      expect(state().style, formal);
      expect(state().selectionComplete, isTrue);
      expect(state().body, isNotEmpty);
    });

    test('choosing issues alone asks the server nothing and writes no text', () {
      notifier().setIssues([housing, lock]);

      expect(composeRequests, isEmpty);
      expect(state().issues, [housing, lock]);
      expect(state().style, isNull);
      expect((state().subject, state().body, state().footer), ('', '', null));
      expect(state().selectionComplete, isFalse); // a style is still to be chosen
    });

    test('issues with a style chosen is complete, but not ready until there is text and a name', () async {
      notifier().setIssues([housing]);
      expect(state().hasChosenContent, isFalse);

      await notifier().chooseStyle(passionate);

      expect(state().hasChosenContent, isTrue);
      expect(state().isContentReady, isFalse); // no name yet
    });

    test('choosing a style with no issues chosen asks the server nothing', () async {
      final error = await notifier().chooseStyle(formal);

      expect(error, isNull);
      expect(composeRequests, isEmpty);
      expect(state().style, isNull);
    });

    test('the style chosen is the one asked for, and the one the draft holds', () async {
      notifier().setIssues([housing]);

      await notifier().chooseStyle(passionate);

      expect(composeRequests.single['style'], 'passionate-urgent');
      expect(state().style, passionate);
    });

    test('changing the style writes the text again, sending the wording held so the server can keep or replace it', () async {
      await composeIssues([housing, lock]);

      await notifier().chooseStyle(passionate);

      expect(composeRequests, hasLength(2));
      expect(composeRequests.last['style'], 'passionate-urgent');
      expect(composeRequests.last['variants'], containsPair('housing-crisis', 'w2')); // the server decides what to keep
      expect(state().style, passionate);
      expect(state().issues, [housing, lock]);
    });

    test('changing the issues after the text was written takes the text away but keeps the style', () async {
      await composeIssues([housing, lock]);

      notifier().setIssues([housing]);

      expect(state().issues, [housing]);
      expect(state().style, formal); // so the style screen can offer it again
      expect((state().subject, state().body, state().footer), ('', '', null));
      expect(state().hasEditedText, isFalse);
    });

    test('changing the issues while the text is still on its way ignores that answer', () async {
      final slow = Completer<http.Response>();
      composeAnswer = (_) => slow.future;
      notifier().setIssues([housing]);
      final pending = notifier().chooseStyle(formal);

      notifier().setIssues([lock]);
      slow.complete(await defaultIssueAnswer({'topics': ['housing-crisis'], 'variants': <String, String>{}}));
      await pending;

      expect(state().issues, [lock]);
      expect(state().body, isEmpty);
      expect(state().style, isNull); // the style was never applied
    });

    test('with no issue chosen there is no text, and the server is not asked', () async {
      final error = await composeIssues([]);

      expect(error, isNull);
      expect(composeRequests, isEmpty);
      expect(state().issues, isEmpty);
      expect(state().selectionComplete, isFalse);
      expect((state().subject, state().body, state().footer), ('', '', null));
      expect(state().isContentReady, isFalse);
    });

    test('is ready once an issue is chosen and there is a name', () async {
      await composeIssues([housing, lock]);
      expect(state().selectionComplete, isTrue);
      expect(state().isContentReady, isFalse); // no name yet

      notifier().setSenderName('Sam Resident');

      expect(state().isContentReady, isTrue);
      expect(state().isReadyToReview, isTrue);
    });

    test('sends the chosen issues and the wording of those issues only', () async {
      await composeIssues([housing, lock]);
      await composeIssues([lock]); // housing is un-chosen: its wording is remembered but not sent

      expect(state().apiTopics, ['triple-lock']);
      expect(state().variantsInUse, {'triple-lock': 'w2', '_subject': 's2', '_intro': 'i2'});
    });

    test('keeps the wording already shown when another issue is chosen', () async {
      await composeIssues([housing]);
      composeAnswer = (request) async {
        final pinned = Map<String, String>.from(request['variants'] as Map);
        final ids = [for (final id in request['topics'] as List) id as String];
        return ok({
          'topics': ids,
          'variants': {
            '_intro': pinned['_intro'] ?? 'i5',
            for (final id in ids) id: pinned[id] ?? 'w5',
            '_subject': pinned['_subject'] ?? 's5',
          },
          'subject': 'S',
          'body': 'B',
          'footer': 'F',
        });
      };

      await composeIssues([housing, lock]);

      // The second request pinned what the first one returned.
      expect(composeRequests.last['variants'], {'housing-crisis': 'w2', '_subject': 's2', '_intro': 'i2'});
      expect(state().templateVariants['housing-crisis'], 'w2');
      expect(state().templateVariants['_subject'], 's2');
      expect(state().templateVariants['_intro'], 'i2');
      expect(state().templateVariants['triple-lock'], 'w5'); // the new issue got a fresh pick
    });

    test('remembers the wording of an issue that was un-chosen, so choosing it again does not re-roll it', () async {
      await composeIssues([housing, lock]);
      await composeIssues([lock]);

      await composeIssues([housing, lock]);

      expect(composeRequests.last['variants'], containsPair('housing-crisis', 'w2'));
    });

    test('replaces any edits the resident made', () async {
      await composeIssues([housing]);
      notifier().setBody('My own words instead');
      expect(state().hasEditedText, isTrue);

      await composeIssues([housing, lock]);

      expect(state().body, contains('triple-lock'));
      expect(state().hasEditedText, isFalse);
    });

    test('un-choosing every issue empties the selection and the text', () async {
      await composeIssues([housing]);

      await composeIssues([]);

      expect(state().issues, isEmpty);
      expect((state().subject, state().body, state().footer), ('', '', null));
    });

    test('the screen is told to refill its text fields each time the text is replaced', () async {
      final before = state().revision;

      await composeIssues([housing]);
      final afterFirst = state().revision;
      await composeIssues([]);

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

      final first = composeIssues([housing]);
      await composeIssues([lock]);
      slow.complete(await defaultIssueAnswer(composeRequests.first));
      await first;

      expect(state().issues, [lock]);
      expect(state().subject, contains('triple-lock'));
    });

    test('with no connection, says so and leaves the draft as it was', () async {
      composeAnswer = (_) async => throw http.ClientException('offline');

      final error = await composeIssues([housing]);

      expect(error, contains('check your connection'));
      expect(state().subject, isEmpty);
    });

    test("passes on the server's own message, e.g. when too many issues were chosen", () async {
      composeAnswer = (_) async => http.Response(
        jsonEncode({'detail': 'Too many topics for one email. Please choose fewer.'}),
        422,
        headers: {'content-type': 'application/json'},
      );

      final error = await composeIssues([housing]);

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

    test('is sent as the campaign id with the variant shown', () async {
      await notifier().chooseCampaign(green);

      expect(state().apiTopics, ['save-stephens-green']);
      expect(state().variantsInUse, {'save-stephens-green': 'v2'});
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
    test('clears the issues, style, campaign, text and footer', () async {
      await composeIssues([housing]);
      expect(state().style, formal);

      notifier().setIntent(MessageIntent.own);

      expect(state().intent, MessageIntent.own);
      expect(state().issues, isEmpty);
      expect(state().style, isNull);
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
      await composeIssues([housing]);
      final before = state();

      notifier().setIntent(MessageIntent.issues);

      expect(state(), before);
    });

    test('an answer still on its way for the old kind of email is ignored', () async {
      final slow = Completer<http.Response>();
      composeAnswer = (_) => slow.future;

      final pending = composeIssues([housing]);
      notifier().setIntent(MessageIntent.own);
      slow.complete(await defaultIssueAnswer({'topics': ['housing-crisis'], 'variants': <String, String>{}}));
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
    await composeIssues([housing]);
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
