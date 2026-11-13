import 'package:app/models/message_intent.dart';
import 'package:app/providers/draft/draft_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// The issues step: choose issues and the server writes a first draft you can
/// edit. There is nothing to tick: the text appears as soon as an issue is
/// chosen. Nothing here needs an area.
void main() {
  late FakeApi api;

  setUp(() => api = FakeApi());

  // The text fields, in the order they appear: name, subject, message.
  TextField field(WidgetTester tester, int index) => tester.widget<TextField>(find.byType(TextField).at(index));
  String text(WidgetTester tester, int index) => field(tester, index).controller!.text;
  bool continueEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue')).onPressed != null;

  Future<void> openIssues(WidgetTester tester) => openApp(tester, api, path: '/craft/issues');

  Future<void> choose(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('lists the issues, with no draft until one is chosen', (tester) async {
    await openIssues(tester);

    expect(find.text('Housing Crisis'), findsOneWidget);
    expect(find.text('Triple Lock'), findsOneWidget);
    expect(find.text('Choose an issue to get started.'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Subject'), findsNothing);
    expect(continueEnabled(tester), isFalse);
  });

  testWidgets('says what the draft will do', (tester) async {
    await openIssues(tester);

    expect(find.textContaining('asks each councillor what they are doing about it'), findsOneWidget);
  });

  testWidgets('there is nothing to tick: just the issues are listed, before and after choosing one', (tester) async {
    await openIssues(tester);
    expect(find.byType(CheckboxListTile), findsNWidgets(2));

    await choose(tester, 'Housing Crisis');

    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    expect(find.textContaining('proposal'), findsNothing);
  });

  testWidgets('choosing an issue fills in the draft at once, asking the server with no area', (tester) async {
    await openIssues(tester);

    await choose(tester, 'Housing Crisis');

    expect(text(tester, 1), 'Where do you stand on housing-crisis?');
    expect(text(tester, 2), 'About housing-crisis.');
    expect(api.composeRequests.single, {
      'topics': ['housing-crisis'],
      'variants': <String, String>{},
    });
    expect(find.textContaining('Started from a topic template.'), findsOneWidget);
    expect(find.textContaining('Hi <name>,'), findsOneWidget);
  });

  testWidgets('the name is still needed before continuing', (tester) async {
    await openIssues(tester);
    await choose(tester, 'Housing Crisis');
    expect(continueEnabled(tester), isFalse);

    await tester.enterText(find.byType(TextField).at(0), 'Sam Resident');
    await tester.pumpAndSettle();

    expect(continueEnabled(tester), isTrue);
  });

  testWidgets('choosing a second issue writes one draft for both, in the list order', (tester) async {
    await openIssues(tester);
    await choose(tester, 'Triple Lock');

    await choose(tester, 'Housing Crisis');

    expect(api.composeRequests.last['topics'], ['housing-crisis', 'triple-lock']);
    expect(text(tester, 1), 'Where do you stand on housing-crisis and triple-lock?');
    expect(text(tester, 2), 'About housing-crisis.\n\nAbout triple-lock.');
  });

  testWidgets('the wording already shown is sent back so choosing another issue does not change it', (tester) async {
    await openIssues(tester);
    await choose(tester, 'Housing Crisis');

    await choose(tester, 'Triple Lock');

    expect(api.composeRequests.last['variants'], {
      '_intro': 'open-conversation',
      'housing-crisis': 'where-you-stand',
      '_subject': 'stand',
    });
    expect(api.composeRequests.last['topics'], ['housing-crisis', 'triple-lock']);
  });

  testWidgets('un-choosing the only issue takes the draft away again', (tester) async {
    final container = await openApp(tester, api, path: '/craft/issues');
    await choose(tester, 'Housing Crisis');

    await choose(tester, 'Housing Crisis');

    expect(find.widgetWithText(TextField, 'Subject'), findsNothing);
    expect(find.text('Choose an issue to get started.'), findsOneWidget);
    expect(container.read(draftNotifierProvider).issues, isEmpty);
    expect(continueEnabled(tester), isFalse);
  });

  testWidgets('changing the issues after an edit asks first, and Cancel keeps the edit', (tester) async {
    await openIssues(tester);
    await choose(tester, 'Housing Crisis');
    await tester.enterText(find.byType(TextField).at(2), 'My own words instead.');
    await tester.pumpAndSettle();

    await choose(tester, 'Triple Lock');
    expect(find.text('This replaces your edits. Continue?'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Cancel')));
    await tester.pumpAndSettle();

    expect(text(tester, 2), 'My own words instead.');
    expect(api.composeRequests, hasLength(1)); // nothing more was asked of the server
  });

  testWidgets('confirming replaces the edit with the new draft', (tester) async {
    await openIssues(tester);
    await choose(tester, 'Housing Crisis');
    await tester.enterText(find.byType(TextField).at(2), 'My own words instead.');
    await tester.pumpAndSettle();

    await choose(tester, 'Triple Lock');
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Continue')));
    await tester.pumpAndSettle();

    expect(text(tester, 2), 'About housing-crisis.\n\nAbout triple-lock.');
  });

  testWidgets('text left in double square brackets is flagged and blocks continuing', (tester) async {
    await openIssues(tester);
    await choose(tester, 'Housing Crisis');
    await tester.enterText(find.byType(TextField).at(0), 'Sam Resident');
    await tester.pumpAndSettle();
    expect(continueEnabled(tester), isTrue);

    await tester.enterText(find.byType(TextField).at(2), 'Body [[context: fill me in]]');
    await tester.pumpAndSettle();

    expect(find.textContaining('double square brackets'), findsOneWidget);
    expect(continueEnabled(tester), isFalse);
  });

  testWidgets('Continue opens the council step', (tester) async {
    await openIssues(tester);
    await choose(tester, 'Housing Crisis');
    await tester.enterText(find.byType(TextField).at(0), 'Sam Resident');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Select your council'), findsOneWidget);
    expect(find.text('Fingal County Council'), findsOneWidget);
  });

  testWidgets('says this is step 1 of 5', (tester) async {
    await openIssues(tester);

    expect(find.textContaining('Step 1 of 5'), findsOneWidget);
  });

  group('when there is nothing to show', () {
    testWidgets('with no issues ready, says so and offers writing your own', (tester) async {
      api.issues = [];
      await openIssues(tester);

      expect(find.text('No issues are available yet. You can write your own email instead.'), findsOneWidget);
      expect(find.text('Choose an issue to get started.'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Write my own email'), findsOneWidget);
    });

    testWidgets('Write my own email there switches to writing your own', (tester) async {
      api.issues = [];
      final container = await openApp(tester, api, path: '/craft/issues');

      await tester.tap(find.widgetWithText(FilledButton, 'Write my own email'));
      await tester.pumpAndSettle();

      expect(container.read(draftNotifierProvider).intent, MessageIntent.own);
      expect(find.widgetWithText(TextField, 'Subject'), findsOneWidget);
    });

    testWidgets('if the issues cannot be loaded, says so and can try again', (tester) async {
      api.topicsFail = true;
      await openIssues(tester);

      expect(find.textContaining('Could not load'), findsOneWidget);

      api.topicsFail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Housing Crisis'), findsOneWidget);
    });
  });

  testWidgets('points anyone who wants to say something different to writing their own email', (tester) async {
    final container = await openApp(tester, api, path: '/craft/issues');

    expect(find.text('Want to say something different? Write your own email.'), findsOneWidget);
    await tester.tap(find.text('Want to say something different? Write your own email.'));
    await tester.pumpAndSettle();

    expect(container.read(draftNotifierProvider).intent, MessageIntent.own);
    expect(find.widgetWithText(TextField, 'Subject'), findsOneWidget);
  });
}
