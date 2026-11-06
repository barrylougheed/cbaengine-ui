import 'package:app/models/message_intent.dart';
import 'package:app/providers/draft/draft_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// The issues step: choose issues, tick the proposals you support, and the
/// server writes a first draft you can edit. The text only appears once every
/// chosen issue has a proposal ticked. Nothing here needs an area.
void main() {
  const ban = 'a ban on vulture funds bulk purchasing properties';
  const register = 'a public register to monitor house bidding';

  late FakeApi api;

  setUp(() => api = FakeApi());

  // The text fields, in the order they appear: name, subject, message.
  TextField field(WidgetTester tester, int index) => tester.widget<TextField>(find.byType(TextField).at(index));
  String text(WidgetTester tester, int index) => field(tester, index).controller!.text;
  bool continueEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue')).onPressed != null;

  Future<void> openIssues(WidgetTester tester) => openApp(tester, api, path: '/craft/issues');

  Future<void> tick(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('lists the issues, with no proposals showing until an issue is chosen', (tester) async {
    await openIssues(tester);

    expect(find.text('Housing Crisis'), findsOneWidget);
    expect(find.text('Triple Lock'), findsOneWidget);
    expect(find.text(ban), findsNothing);
    expect(find.text('Choose an issue to get started.'), findsOneWidget);
    expect(continueEnabled(tester), isFalse);
  });

  testWidgets('says what ticking a proposal does', (tester) async {
    await openIssues(tester);

    expect(find.textContaining('Each councillor will be asked whether they would support'), findsOneWidget);
  });

  testWidgets('choosing an issue shows its proposals, and there is still no draft', (tester) async {
    await openIssues(tester);

    await tick(tester, 'Housing Crisis');

    expect(find.text(ban), findsOneWidget);
    expect(find.text(register), findsOneWidget);
    expect(find.text('Tick at least one proposal for each issue to see your email.'), findsOneWidget);
    expect(api.composeRequests, isEmpty);
    expect(find.widgetWithText(TextField, 'Subject'), findsNothing);
  });

  testWidgets('ticking a proposal fills in the draft, asking the server with no area', (tester) async {
    await openIssues(tester);
    await tick(tester, 'Housing Crisis');

    await tick(tester, ban);

    expect(text(tester, 1), 'Where do you stand on housing-crisis?');
    expect(text(tester, 2), 'About housing-crisis: ban-bulk-purchases');
    expect(api.composeRequests.single, {
      'topics': [
        {
          'id': 'housing-crisis',
          'proposals': ['ban-bulk-purchases'],
        },
      ],
      'variants': <String, String>{},
    });
    expect(find.textContaining('Started from a topic template.'), findsOneWidget);
    expect(find.textContaining('Dear Councillor <name>,'), findsOneWidget);
  });

  testWidgets('the name is still needed before continuing', (tester) async {
    await openIssues(tester);
    await tick(tester, 'Housing Crisis');
    await tick(tester, ban);
    expect(continueEnabled(tester), isFalse);

    await tester.enterText(find.byType(TextField).at(0), 'Sam Resident');
    await tester.pumpAndSettle();

    expect(continueEnabled(tester), isTrue);
  });

  testWidgets('every chosen issue needs a proposal ticked: a second issue with none hides the draft again', (
    tester,
  ) async {
    await openIssues(tester);
    await tick(tester, 'Housing Crisis');
    await tick(tester, ban);
    expect(find.widgetWithText(TextField, 'Subject'), findsOneWidget);

    await tick(tester, 'Triple Lock');

    expect(find.widgetWithText(TextField, 'Subject'), findsNothing);
    expect(find.text('Tick at least one proposal for each issue to see your email.'), findsOneWidget);
    expect(continueEnabled(tester), isFalse);

    await tick(tester, 'keeping the triple lock');

    expect(api.composeRequests.last['topics'], [
      {
        'id': 'housing-crisis',
        'proposals': ['ban-bulk-purchases'],
      },
      {
        'id': 'triple-lock',
        'proposals': ['keep-it'],
      },
    ]);
    expect(text(tester, 1), 'Where do you stand on housing-crisis and triple-lock?');
  });

  testWidgets('the wording already shown is sent back so ticking more does not change it', (tester) async {
    await openIssues(tester);
    await tick(tester, 'Housing Crisis');
    await tick(tester, ban);

    await tick(tester, register);

    expect(api.composeRequests.last['variants'], {'housing-crisis': 'view', '_subject': 'stand'});
    expect(api.composeRequests.last['topics'], [
      {
        'id': 'housing-crisis',
        'proposals': ['ban-bulk-purchases', 'public-register'],
      },
    ]);
  });

  testWidgets('un-ticking the only proposal takes the draft away again', (tester) async {
    await openIssues(tester);
    await tick(tester, 'Housing Crisis');
    await tick(tester, ban);

    await tick(tester, ban);

    expect(find.widgetWithText(TextField, 'Subject'), findsNothing);
    expect(find.text('Tick at least one proposal for each issue to see your email.'), findsOneWidget);
  });

  testWidgets('un-choosing an issue hides its proposals and drops its ticks', (tester) async {
    final container = await openApp(tester, api, path: '/craft/issues');
    await tick(tester, 'Housing Crisis');
    await tick(tester, ban);

    await tick(tester, 'Housing Crisis');

    expect(find.text(ban), findsNothing);
    expect(container.read(draftNotifierProvider).issues, isEmpty);
    expect(container.read(draftNotifierProvider).ticked, isEmpty);
  });

  testWidgets('changing the ticks after an edit asks first, and Cancel keeps the edit', (tester) async {
    await openIssues(tester);
    await tick(tester, 'Housing Crisis');
    await tick(tester, ban);
    await tester.enterText(find.byType(TextField).at(2), 'My own words instead.');
    await tester.pumpAndSettle();

    await tick(tester, register);
    expect(find.text('This replaces your edits. Continue?'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Cancel')));
    await tester.pumpAndSettle();

    expect(text(tester, 2), 'My own words instead.');
    expect(api.composeRequests, hasLength(1)); // nothing more was asked of the server
  });

  testWidgets('confirming replaces the edit with the new draft', (tester) async {
    await openIssues(tester);
    await tick(tester, 'Housing Crisis');
    await tick(tester, ban);
    await tester.enterText(find.byType(TextField).at(2), 'My own words instead.');
    await tester.pumpAndSettle();

    await tick(tester, register);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Continue')));
    await tester.pumpAndSettle();

    expect(text(tester, 2), 'About housing-crisis: ban-bulk-purchases, public-register');
  });

  testWidgets('text left in double square brackets is flagged and blocks continuing', (tester) async {
    await openIssues(tester);
    await tick(tester, 'Housing Crisis');
    await tick(tester, ban);
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
    await tick(tester, 'Housing Crisis');
    await tick(tester, ban);
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

  testWidgets('points anyone who disagrees with the proposals to writing their own email', (tester) async {
    final container = await openApp(tester, api, path: '/craft/issues');

    expect(find.text('Disagree with these? Write your own email.'), findsOneWidget);
    await tester.tap(find.text('Disagree with these? Write your own email.'));
    await tester.pumpAndSettle();

    expect(container.read(draftNotifierProvider).intent, MessageIntent.own);
    expect(find.widgetWithText(TextField, 'Subject'), findsOneWidget);
  });
}
