import 'dart:async';
import 'dart:convert';

import 'package:app/app.dart';
import 'package:app/models/council.dart';
import 'package:app/models/councillor_preview.dart';
import 'package:app/models/draft.dart';
import 'package:app/models/lea.dart';
import 'package:app/providers/core_providers.dart';
import 'package:app/providers/draft/draft_notifier.dart';
import 'package:app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The compose step: pick topics (the server writes a first draft) or write
/// your own, add a name, and only then continue.
void main() {
  const topicsJson = {
    'topics': [
      {'id': 'housing-crisis', 'title': 'Housing Crisis'},
      {'id': 'save-stephens-green', 'title': "Save Stephen's Green"},
    ],
    'email_layout': {'greeting_format': 'Dear Councillor {name},', 'sign_off': 'Kind regards,'},
  };

  late ProviderContainer container;
  late List<Map<String, dynamic>> composeRequests;

  http.Response jsonResponse(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  Future<http.Response> handle(http.Request request) async {
    switch (request.url.path) {
      case '/topics':
        return jsonResponse(topicsJson);
      case '/topics/compose':
        final asked = jsonDecode(request.body) as Map<String, dynamic>;
        composeRequests.add(asked);
        final topics = List<String>.from(asked['topics'] as List);
        return jsonResponse({
          'topics': topics,
          'variants': {for (final id in topics) id: 'v1'},
          'subject': topics.length == 1 ? 'Subject for ${topics.single}' : 'Your stance on ${topics.join(' and ')}',
          'body': topics.map((id) => 'Body for $id.').join('\n\n'),
          'footer': 'Started from a topic template.',
        });
      default:
        return jsonResponse({'councils': <Object>[]});
    }
  }

  Future<void> openCompose(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    composeRequests = [];
    container = ProviderContainer.test(
      retry: noAutomaticRetry,
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs), httpClientProvider.overrideWithValue(MockClient(handle))],
    );
    container.read(draftNotifierProvider.notifier)
      ..selectCouncil(const Council(id: 'fingal-county-council', name: 'Fingal County Council'))
      ..selectLea(
        const Lea(
          id: 'fingal-balbriggan',
          name: 'Balbriggan',
          council: 'Fingal County Council',
          councillors: [CouncillorPreview(name: 'A Councillor', party: 'Independent')],
        ),
      );

    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const CbaEngineApp()));
    await tester.pumpAndSettle();
    unawaited(container.read(routerProvider).push('/compose'));
    await tester.pumpAndSettle();
  }

  // The text fields, in the order they appear: name, subject, message.
  TextField field(WidgetTester tester, int index) => tester.widget<TextField>(find.byType(TextField).at(index));
  String text(WidgetTester tester, int index) => field(tester, index).controller!.text;
  bool continueEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue')).onPressed != null;

  testWidgets('offers the topics and writing your own, and cannot continue yet', (tester) async {
    await openCompose(tester);

    expect(find.text('Select a topic'), findsOneWidget);
    expect(find.text('Write your own'), findsOneWidget);
    expect(find.text('Housing Crisis'), findsOneWidget);
    expect(find.text("Save Stephen's Green"), findsOneWidget);
    expect(find.text('Pick a topic to see the draft.'), findsOneWidget);
    expect(continueEnabled(tester), isFalse);
  });

  testWidgets('ticking a topic fills in the draft; the name is still needed before continuing', (tester) async {
    await openCompose(tester);

    await tester.tap(find.text('Housing Crisis'));
    await tester.pumpAndSettle();

    expect(text(tester, 1), 'Subject for housing-crisis');
    expect(text(tester, 2), 'Body for housing-crisis.');
    expect(find.textContaining('Started from a topic template.'), findsOneWidget);
    expect(find.textContaining('Dear Councillor <name>,'), findsOneWidget);
    expect(continueEnabled(tester), isFalse);

    await tester.enterText(find.byType(TextField).at(0), 'Sam Resident');
    await tester.pumpAndSettle();

    expect(continueEnabled(tester), isTrue);
  });

  testWidgets('ticking several topics asks for them all together', (tester) async {
    await openCompose(tester);

    await tester.tap(find.text('Housing Crisis'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Save Stephen's Green"));
    await tester.pumpAndSettle();

    expect(composeRequests.last['topics'], ['housing-crisis', 'save-stephens-green']);
    // The variant already shown for the first topic is sent back to be kept.
    expect(composeRequests.last['variants'], {'housing-crisis': 'v1'});
    expect(text(tester, 1), 'Your stance on housing-crisis and save-stephens-green');
  });

  testWidgets('changing the topics after an edit asks first, and Cancel keeps the edit', (tester) async {
    await openCompose(tester);
    await tester.tap(find.text('Housing Crisis'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(2), 'My own words instead.');
    await tester.pumpAndSettle();

    await tester.tap(find.text("Save Stephen's Green"));
    await tester.pumpAndSettle();
    expect(find.text('This replaces your edits. Continue?'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Cancel')));
    await tester.pumpAndSettle();

    expect(text(tester, 2), 'My own words instead.');
    expect(composeRequests, hasLength(1)); // nothing more was asked of the server
  });

  testWidgets('confirming replaces the edit with the new draft', (tester) async {
    await openCompose(tester);
    await tester.tap(find.text('Housing Crisis'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(2), 'My own words instead.');
    await tester.pumpAndSettle();

    await tester.tap(find.text("Save Stephen's Green"));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Continue')));
    await tester.pumpAndSettle();

    expect(text(tester, 2), 'Body for housing-crisis.\n\nBody for save-stephens-green.');
  });

  testWidgets('unticking every topic empties the draft again', (tester) async {
    await openCompose(tester);
    await tester.tap(find.text('Housing Crisis'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Housing Crisis'));
    await tester.pumpAndSettle();

    expect(find.text('Pick a topic to see the draft.'), findsOneWidget);
    expect(container.read(draftNotifierProvider).subject, '');
  });

  testWidgets('writing your own shows empty fields and no footer', (tester) async {
    await openCompose(tester);
    await tester.tap(find.text('Housing Crisis'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Write your own'));
    await tester.pumpAndSettle();
    // The text came from a topic and was not edited, so there was nothing to ask about.

    expect(find.text('Housing Crisis'), findsNothing); // the topic list is gone
    expect(text(tester, 1), '');
    expect(text(tester, 2), '');
    expect(find.textContaining('Started from a topic template.'), findsNothing);
    expect(container.read(draftNotifierProvider).mode, ComposeMode.ownWords);
  });

  testWidgets('switching away from text you wrote asks before clearing it', (tester) async {
    await openCompose(tester);
    await tester.tap(find.text('Write your own'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(2), 'Something I wrote.');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select a topic'));
    await tester.pumpAndSettle();
    expect(find.text('This clears what you have written. Continue?'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Cancel')));
    await tester.pumpAndSettle();

    expect(container.read(draftNotifierProvider).mode, ComposeMode.ownWords);
    expect(text(tester, 2), 'Something I wrote.');
  });

  testWidgets('text left in double square brackets is flagged and blocks continuing', (tester) async {
    await openCompose(tester);
    await tester.tap(find.text('Write your own'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Sam Resident');
    await tester.enterText(find.byType(TextField).at(1), 'Subject');
    await tester.enterText(find.byType(TextField).at(2), 'Body');
    await tester.pumpAndSettle();
    expect(continueEnabled(tester), isTrue);

    await tester.enterText(find.byType(TextField).at(2), 'Body [[context: fill me in]]');
    await tester.pumpAndSettle();

    expect(find.textContaining('double square brackets'), findsOneWidget);
    expect(continueEnabled(tester), isFalse);
  });
}
