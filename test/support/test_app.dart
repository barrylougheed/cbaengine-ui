import 'dart:async';
import 'dart:convert';

import 'package:app/app.dart';
import 'package:app/models/message_intent.dart';
import 'package:app/providers/core_providers.dart';
import 'package:app/providers/draft/draft_notifier.dart';
import 'package:app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A fake CBAEngine API for screen tests: the issues (with proposals), the
/// campaigns, composing text for both, and the councils and areas. Each test
/// changes what it needs (an empty list, a failure) and reads what the app asked.
class FakeApi {
  /// GET /topics: the issues ready for residents.
  List<Map<String, Object?>> issues = [
    {
      'id': 'housing-crisis',
      'title': 'Housing Crisis',
      'proposals': [
        {'id': 'ban-bulk-purchases', 'text': 'a ban on vulture funds bulk purchasing properties'},
        {'id': 'public-register', 'text': 'a public register to monitor house bidding'},
      ],
    },
    {
      'id': 'triple-lock',
      'title': 'Triple Lock',
      'proposals': [
        {'id': 'keep-it', 'text': 'keeping the triple lock'},
        {'id': 'review-it', 'text': 'a review of the triple lock'},
      ],
    },
  ];

  /// GET /campaigns: the campaigns ready for residents.
  List<Map<String, Object?>> campaigns = [
    {
      'id': 'save-stephens-green',
      'title': "Save Stephen's Green",
      'summary': 'Keep the Green open to everyone.',
      'link': 'https://example.org/green',
    },
    {'id': 'give-us-the-night', 'title': 'Give us the night', 'summary': 'A livelier night-time city.', 'link': null},
  ];

  bool topicsFail = false;
  bool campaignsFail = false;
  bool councilsFail = false;

  /// Makes composing a campaign's email fail, as if the campaign were no longer open.
  bool campaignComposeFails = false;

  final List<Map<String, dynamic>> composeRequests = [];
  final List<Map<String, dynamic>> campaignRequests = [];

  http.Response json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  Future<http.Response> handle(http.Request request) async {
    final path = request.url.path;
    switch (path) {
      case '/topics':
        if (topicsFail) return json({'detail': 'down'}, 500);
        return json({
          'topics': issues,
          'email_layout': {'greeting_format': 'Dear Councillor {name},', 'sign_off': 'Kind regards,'},
        });
      case '/topics/compose':
        final asked = jsonDecode(request.body) as Map<String, dynamic>;
        composeRequests.add(asked);
        final selection = [for (final topic in asked['topics'] as List) topic as Map<String, dynamic>];
        final pinned = Map<String, String>.from(asked['variants'] as Map);
        final ids = [for (final topic in selection) topic['id'] as String];
        return json({
          'topics': ids,
          'variants': {for (final id in ids) id: pinned[id] ?? 'view', '_subject': pinned['_subject'] ?? 'stand'},
          'subject': 'Where do you stand on ${ids.join(' and ')}?',
          'body': [
            for (final topic in selection) 'About ${topic['id']}: ${(topic['proposals'] as List).join(', ')}',
          ].join('\n\n'),
          'footer': 'Started from a topic template.',
        });
      case '/campaigns':
        if (campaignsFail) return json({'detail': 'down'}, 500);
        return json({'campaigns': campaigns});
      case '/councils':
        if (councilsFail) return json({'detail': 'down'}, 500);
        return json({
          'councils': [
            {'id': 'fingal-county-council', 'name': 'Fingal County Council', 'area_count': 2, 'councillor_count': 5},
            {'id': 'dublin-city-council', 'name': 'Dublin City Council', 'area_count': 11, 'councillor_count': 63},
          ],
        });
      case '/councils/fingal-county-council/leas':
        return json({
          'leas': [
            {
              'id': 'fingal-balbriggan',
              'name': 'Balbriggan',
              'council': 'Fingal County Council',
              'councillors': [
                {'name': 'Ann One', 'party': 'Fine Gael'},
                {'name': 'Bob Two', 'party': 'Labour Party'},
              ],
            },
            {
              'id': 'fingal-castleknock',
              'name': 'Castleknock',
              'council': 'Fingal County Council',
              'councillors': [
                {'name': 'Cora Three', 'party': 'Independent'},
              ],
            },
          ],
        });
    }
    final campaign = RegExp(r'^/campaigns/([a-z-]+)/compose$').firstMatch(path);
    if (campaign != null) {
      if (campaignComposeFails) return json({'detail': 'Campaign not found.'}, 404);
      final id = campaign.group(1)!;
      final asked = jsonDecode(request.body) as Map<String, dynamic>;
      campaignRequests.add({'id': id, ...asked});
      final pinned = Map<String, String>.from(asked['variants'] as Map);
      final title = (campaigns.firstWhere((c) => c['id'] == id)['title']) as String;
      return json({
        'topics': [id],
        'variants': {id: pinned[id] ?? 'v1'},
        'subject': 'Subject for $id',
        'body': 'Body for $id.',
        'footer': "Sent as part of the '$title' campaign.",
      });
    }
    return json({'detail': 'not found'}, 404);
  }
}

/// Opens the whole app against [api] in a tall window (so nothing needs
/// scrolling to be found). [prepare] runs before the first frame, to put the
/// draft where a test wants it; [path] then opens a screen on top of Home.
Future<ProviderContainer> openApp(
  WidgetTester tester,
  FakeApi api, {
  void Function(DraftNotifier draft)? prepare,
  String? path,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer.test(
    retry: noAutomaticRetry,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      httpClientProvider.overrideWithValue(MockClient(api.handle)),
      ...overrides,
    ],
  );
  if (prepare != null) prepare(container.read(draftNotifierProvider.notifier));

  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const CbaEngineApp()));
  await tester.pumpAndSettle();
  if (path != null) {
    unawaited(container.read(routerProvider).push(path));
    await tester.pumpAndSettle();
  }
  return container;
}

/// A draft whose first step is finished: the resident's own words with a name,
/// so the council and area steps are open to them.
void finishedOwnWordsEmail(DraftNotifier draft) {
  draft
    ..setIntent(MessageIntent.own)
    ..setSenderName('Sam Resident')
    ..setSubject('My subject')
    ..setBody('My message.');
}
