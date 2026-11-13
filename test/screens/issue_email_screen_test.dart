import 'package:app/providers/draft/draft_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// The last part of the first step for an email about issues: the text the
/// server wrote for the topics and style chosen, which the resident can edit,
/// and their name. Nothing here needs an area.
void main() {
  late FakeApi api;

  setUp(() => api = FakeApi());

  // The text fields, in the order they appear: name, subject, message.
  TextField field(WidgetTester tester, int index) => tester.widget<TextField>(find.byType(TextField).at(index));
  String text(WidgetTester tester, int index) => field(tester, index).controller!.text;
  bool continueEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue')).onPressed != null;

  /// Opens the app on the categories and walks to the editor, as a resident does.
  Future<ProviderContainer> openEditor(
    WidgetTester tester, {
    List<String> topics = const ['Housing Crisis'],
    String style = 'Formal & Direct',
  }) async {
    final container = await openApp(tester, api, path: '/craft/issues');
    await walkToTheIssueEmail(tester, topics: topics, style: style);
    return container;
  }

  testWidgets('fills in the subject and message the server wrote, and the footer it adds', (tester) async {
    await openEditor(tester);

    expect(text(tester, 1), 'Where do you stand on housing-crisis?');
    expect(text(tester, 2), 'About housing-crisis.');
    expect(find.textContaining('Started from a topic template.'), findsOneWidget);
    expect(find.textContaining('Hi <name>,'), findsOneWidget);
  });

  testWidgets('says this is step 1 of 5', (tester) async {
    await openEditor(tester);

    expect(find.textContaining('Step 1 of 5'), findsOneWidget);
  });

  testWidgets('says which topics and which style the email is in', (tester) async {
    await openEditor(tester, topics: const ['Housing Crisis', 'Homelessness'], style: 'Passionate & Urgent');

    expect(find.text('Topics: Homelessness, Housing Crisis'), findsOneWidget);
    expect(find.text('Style: Passionate & Urgent'), findsOneWidget);
  });

  testWidgets('the text was written in the style chosen, with no area asked for', (tester) async {
    await openEditor(tester, style: 'Solution-Oriented');

    expect(api.composeRequests.single, {
      'topics': ['housing-crisis'],
      'style': 'solution-oriented',
      'variants': <String, String>{},
    });
  });

  testWidgets('the name is still needed before continuing', (tester) async {
    await openEditor(tester);
    expect(continueEnabled(tester), isFalse);

    await tester.enterText(find.byType(TextField).at(0), 'Sam Resident');
    await tester.pumpAndSettle();

    expect(continueEnabled(tester), isTrue);
  });

  testWidgets('text left in double square brackets is flagged and blocks continuing', (tester) async {
    await openEditor(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Sam Resident');
    await tester.pumpAndSettle();
    expect(continueEnabled(tester), isTrue);

    await tester.enterText(find.byType(TextField).at(2), 'Body [[context: fill me in]]');
    await tester.pumpAndSettle();

    expect(find.textContaining('double square brackets'), findsOneWidget);
    expect(continueEnabled(tester), isFalse);
  });

  testWidgets('what the resident edits is kept as their own', (tester) async {
    final container = await openEditor(tester);

    await tester.enterText(find.byType(TextField).at(2), 'My own words instead.');
    await tester.pumpAndSettle();

    final draft = container.read(draftNotifierProvider);
    expect(draft.body, 'My own words instead.');
    expect(draft.hasEditedText, isTrue);
  });

  testWidgets('Continue opens the council step', (tester) async {
    await openEditor(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Sam Resident');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Select your council'), findsOneWidget);
    expect(find.text('Fingal County Council'), findsOneWidget);
  });

  testWidgets('Change style goes back to the styles, with the current one chosen, and the edit kept if it is kept', (
    tester,
  ) async {
    final container = await openEditor(tester);
    await tester.enterText(find.byType(TextField).at(2), 'My own words instead.');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Change style'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a letter style'), findsWidgets);
    expect(tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>)).groupValue, 'formal-direct');
    expect(container.read(draftNotifierProvider).body, 'My own words instead.');
  });

  testWidgets('Change topics goes back to the categories, with the choice kept', (tester) async {
    final container = await openEditor(tester);

    await tester.tap(find.text('Change topics'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a category'), findsWidgets);
    expect(find.text('You have chosen: Housing Crisis'), findsOneWidget);
    expect([for (final issue in container.read(draftNotifierProvider).issues) issue.id], ['housing-crisis']);
  });

  testWidgets('with no text written, a raw visit is sent back to the start of the choice', (tester) async {
    await openApp(tester, api, path: '/craft/issues/email');

    expect(find.text('Choose a category'), findsWidgets);
    expect(find.widgetWithText(TextField, 'Subject'), findsNothing);
  });

  testWidgets('starting over from the editor goes home without an error', (tester) async {
    await openEditor(tester);

    await tester.tap(find.text('CBAEngine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start over'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('What would you like to do?'), findsOneWidget);
  });
}
