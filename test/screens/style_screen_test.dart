import 'dart:async';

import 'package:app/models/style_summary.dart';
import 'package:app/models/topic_summary.dart';
import 'package:app/providers/draft/draft_notifier.dart';
import 'package:app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// The third screen of an email about issues: choose a letter style, the tone
/// the whole email is written in. The server writes the text when the style is
/// chosen; nothing here needs an area.
void main() {
  late FakeApi api;
  const homelessness = TopicSummary(id: 'homelessness', title: 'Homelessness', category: 'housing');
  const lock = TopicSummary(id: 'triple-lock', title: 'Triple Lock', category: 'geopolitics');
  const formal = StyleSummary(
    id: 'formal-direct',
    title: 'Formal & Direct',
    description: 'Respectful and to the point.',
  );
  const passionate = StyleSummary(
    id: 'passionate-urgent',
    title: 'Passionate & Urgent',
    description: 'Strong feeling, and a call to act now.',
  );

  setUp(() => api = FakeApi());

  /// Opens the style screen with [chosen] issues already chosen, as it is reached.
  Future<ProviderContainer> openStyles(
    WidgetTester tester, {
    List<TopicSummary> chosen = const [homelessness],
    void Function(DraftNotifier)? alsoPrepare,
  }) => openApp(
    tester,
    api,
    path: '/craft/issues/style',
    prepare: (draft) {
      draft.setIssues(chosen);
      alsoPrepare?.call(draft);
    },
  );

  bool continueEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue')).onPressed != null;

  /// The id of the style marked as chosen on screen, or null when none is.
  String? chosenStyle(WidgetTester tester) =>
      tester.widget<RadioGroup<String>>(find.byType(RadioGroup<String>)).groupValue;

  testWidgets('offers each style with what it sounds like, in the server\'s order', (tester) async {
    await openStyles(tester);

    expect(find.text('Choose a letter style'), findsWidgets);
    for (final title in [
      'Formal & Direct',
      'Passionate & Urgent',
      'Community Focused',
      'Solution-Oriented',
      'Disappointed & Concerned',
      'Factual & Data-Driven',
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('Respectful and to the point.'), findsOneWidget);
    expect(find.text('Strong feeling, and a call to act now.'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Formal & Direct')).dy,
      lessThan(tester.getTopLeft(find.text('Passionate & Urgent')).dy),
    );
  });

  testWidgets('says this is step 1 of 5, and which topics the email is about', (tester) async {
    await openStyles(tester, chosen: const [homelessness, lock]);

    expect(find.textContaining('Step 1 of 5'), findsOneWidget);
    expect(find.text('Topics: Homelessness, Triple Lock'), findsOneWidget);
  });

  testWidgets('nothing is chosen at first, and so there is nothing to continue with', (tester) async {
    await openStyles(tester);

    expect(chosenStyle(tester), isNull);
    expect(continueEnabled(tester), isFalse);
    expect(api.composeRequests, isEmpty);
  });

  testWidgets('choosing a style marks it, and allows continuing, without asking the server yet', (tester) async {
    await openStyles(tester);

    await tester.tap(find.text('Passionate & Urgent'));
    await tester.pumpAndSettle();

    expect(chosenStyle(tester), 'passionate-urgent');
    expect(continueEnabled(tester), isTrue);
    expect(api.composeRequests, isEmpty);
  });

  testWidgets('Continue writes the text in that style, then opens the editor', (tester) async {
    final container = await openStyles(tester, chosen: const [homelessness, lock]);
    await tester.tap(find.text('Passionate & Urgent'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(api.composeRequests.single, {
      'topics': ['homelessness', 'triple-lock'],
      'style': 'passionate-urgent',
      'variants': <String, String>{},
    });
    final draft = container.read(draftNotifierProvider);
    expect(draft.style, passionate);
    expect(draft.body, 'About homelessness.\n\nAbout triple-lock.');
    expect(find.widgetWithText(TextField, 'Subject'), findsOneWidget); // the editor
  });

  group('coming back to this screen', () {
    /// A draft with text written in the formal style, as it is after the editor.
    Future<ProviderContainer> openAfterWriting(WidgetTester tester) async {
      final container = await openApp(tester, api, prepare: (draft) => draft.setIssues(const [homelessness]));
      await container.read(draftNotifierProvider.notifier).chooseStyle(formal);
      unawaited(container.read(routerProvider).push('/craft/issues/style'));
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('shows the style the text is in as chosen', (tester) async {
      await openAfterWriting(tester);

      expect(chosenStyle(tester), 'formal-direct');
      expect(continueEnabled(tester), isTrue);
    });

    testWidgets('carrying on with the same style keeps the text, and any edits, without asking the server', (
      tester,
    ) async {
      final container = await openAfterWriting(tester);
      container.read(draftNotifierProvider.notifier).setBody('My own words instead.');
      final requestsBefore = api.composeRequests.length;

      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(api.composeRequests, hasLength(requestsBefore));
      expect(container.read(draftNotifierProvider).body, 'My own words instead.');
      expect(find.widgetWithText(TextField, 'Subject'), findsOneWidget);
    });

    testWidgets('changing the style writes the text again, with no question if it was not edited', (tester) async {
      final container = await openAfterWriting(tester);

      await tester.tap(find.text('Passionate & Urgent'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(api.composeRequests.last['style'], 'passionate-urgent');
      expect(container.read(draftNotifierProvider).style, passionate);
    });

    testWidgets('changing the style after an edit asks first, and Cancel keeps the edit', (tester) async {
      final container = await openAfterWriting(tester);
      container.read(draftNotifierProvider.notifier).setBody('My own words instead.');
      final requestsBefore = api.composeRequests.length;

      await tester.tap(find.text('Passionate & Urgent'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();
      expect(find.text('This replaces your edits. Continue?'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Cancel')));
      await tester.pumpAndSettle();

      expect(api.composeRequests, hasLength(requestsBefore));
      expect(container.read(draftNotifierProvider).body, 'My own words instead.');
      expect(container.read(draftNotifierProvider).style, formal);
    });

    testWidgets('confirming replaces the edit with text in the new style', (tester) async {
      final container = await openAfterWriting(tester);
      container.read(draftNotifierProvider.notifier).setBody('My own words instead.');

      await tester.tap(find.text('Passionate & Urgent'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Continue')));
      await tester.pumpAndSettle();

      final draft = container.read(draftNotifierProvider);
      expect(draft.style, passionate);
      expect(draft.body, 'About homelessness.');
      expect(draft.hasEditedText, isFalse);
    });

    testWidgets('after the topics changed, the same style writes the text for the new topics', (tester) async {
      final container = await openAfterWriting(tester);
      container.read(draftNotifierProvider.notifier).setIssues(const [homelessness, lock]);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(api.composeRequests.last['topics'], ['homelessness', 'triple-lock']);
      expect(container.read(draftNotifierProvider).body, 'About homelessness.\n\nAbout triple-lock.');
    });
  });

  testWidgets('a way to change the topics', (tester) async {
    await openStyles(tester);

    await tester.tap(find.text('Change topics'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a category'), findsWidgets);
  });

  testWidgets('with no topic chosen, a raw visit is sent back to choose one', (tester) async {
    await openApp(tester, api, path: '/craft/issues/style');

    expect(find.text('Choose a category'), findsWidgets);
    expect(find.text('Choose a letter style'), findsNothing);
  });

  testWidgets('if the text cannot be written, says so, stays here, and can try again', (tester) async {
    api.issueComposeFails = 'Too many topics for one email. Please choose fewer.';
    await openStyles(tester);
    await tester.tap(find.text('Formal & Direct'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Too many topics for one email. Please choose fewer.'), findsOneWidget);
    expect(find.text('Choose a letter style'), findsWidgets);
    expect(find.widgetWithText(TextField, 'Subject'), findsNothing);
  });

  testWidgets('if the styles cannot be loaded, says so and can try again', (tester) async {
    api.topicsFail = true;
    await openStyles(tester);

    expect(find.textContaining('Could not load'), findsOneWidget);

    api.topicsFail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Formal & Direct'), findsOneWidget);
  });
}
