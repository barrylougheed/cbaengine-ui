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

/// A fake CBAEngine API for screen tests: the categories, issues and letter
/// styles, the campaigns, composing text for issues and campaigns, and the
/// councils and areas. Each test changes what it needs (an empty list, a
/// failure) and reads what the app asked.
class FakeApi {
  /// GET /topics: the issues ready for residents, alphabetically by title.
  List<Map<String, Object?>> issues = [
    {'id': 'homelessness', 'title': 'Homelessness', 'category': 'housing'},
    {'id': 'housing-crisis', 'title': 'Housing Crisis', 'category': 'housing'},
    {'id': 'triple-lock', 'title': 'Triple Lock', 'category': 'geopolitics'},
  ];

  /// GET /topics: the categories that have an issue ready, in the owner's order.
  List<Map<String, Object?>> categories = [
    {'id': 'housing', 'title': 'Housing'},
    {'id': 'geopolitics', 'title': 'Geopolitics'},
  ];

  /// GET /topics: the letter styles, in display order (the first is the default).
  List<Map<String, Object?>> styles = [
    {'id': 'communal', 'title': 'Communal', 'description': 'How the issue affects people in your community.'},
    {
      'id': 'concerned',
      'title': 'Concerned',
      'description': 'Expresses concern about your problem, from lack of progress to decisions made.',
    },
    {'id': 'data-driven', 'title': 'Data-driven', 'description': 'Calm, with the facts, figures and sources.'},
    {'id': 'direct', 'title': 'Direct', 'description': 'Respectful and to the point.'},
    {'id': 'solution-based', 'title': 'Solution-based', 'description': 'Asks for a clear plan and concrete action.'},
    {'id': 'urgent', 'title': 'Urgent', 'description': 'Strong feeling, and a call to act now.'},
  ];

  /// Makes composing an issue email fail with this message (a 422), as the
  /// server does when too many topics were chosen.
  String? issueComposeFails;

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
          'categories': categories,
          'styles': styles,
          'email_layout': {'greeting_format': 'Hi {name},', 'sign_off': 'Kind regards,'},
        });
      case '/topics/compose':
        final asked = jsonDecode(request.body) as Map<String, dynamic>;
        composeRequests.add(asked);
        if (issueComposeFails != null) return json({'detail': issueComposeFails}, 422);
        final pinned = Map<String, String>.from(asked['variants'] as Map);
        final ids = [for (final id in asked['topics'] as List) id as String];
        final style = asked['style'] as String? ?? 'communal';
        return json({
          'topics': ids,
          // In this fake a wording is named after its style, so the ids sent
          // back and forth show which style the text is in.
          'variants': {
            '_intro': pinned['_intro'] ?? 'open-conversation',
            for (final id in ids) id: style,
            '_subject': pinned['_subject'] ?? 'stand',
          },
          'style': style,
          'subject': 'Where do you stand on ${ids.join(' and ')}?',
          'body': [for (final id in ids) 'About $id.'].join('\n\n'),
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

/// Walks the issues flow the way a resident does, to leave the app on the
/// editor with text written: category -> topics -> style -> editor. Returns
/// with the editor open. Uses the FakeApi's first category and its first topic.
Future<void> walkToTheIssueEmail(
  WidgetTester tester, {
  String category = 'Housing',
  List<String> topics = const ['Housing Crisis'],
  String style = 'Direct',
}) async {
  await tester.tap(find.text(category));
  await tester.pumpAndSettle();
  for (final topic in topics) {
    await tester.tap(find.text(topic));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(style));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
  await tester.pumpAndSettle();
}
