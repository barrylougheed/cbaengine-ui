import 'package:app/models/style_summary.dart';
import 'package:app/models/topic_summary.dart';
import 'package:app/providers/draft/draft_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// The second screen of an email about issues: choose one or more topics in the
/// category. Ticking only records the choice (the text is written when a style
/// is chosen), so no request is made. The choice is kept when going back to add
/// a topic from another category.
void main() {
  late FakeApi api;
  const direct = StyleSummary(id: 'direct', title: 'Direct', description: 'Respectful and to the point.');
  const homelessness = TopicSummary(id: 'homelessness', title: 'Homelessness', category: 'housing');

  setUp(() => api = FakeApi());

  Future<ProviderContainer> openHousing(WidgetTester tester) =>
      openApp(tester, api, path: '/craft/issues/category/housing');

  bool continueEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue')).onPressed != null;

  Future<void> tick(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the category, and its topics alphabetically, each a tick box and none ticked', (tester) async {
    await openHousing(tester);

    expect(find.text('Housing'), findsWidgets);
    expect(find.byType(CheckboxListTile), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('Homelessness')).dy,
      lessThan(tester.getTopLeft(find.text('Housing Crisis')).dy),
    );
    expect(find.text('Triple Lock'), findsNothing); // that is Geopolitics
    for (final box in tester.widgetList<CheckboxListTile>(find.byType(CheckboxListTile))) {
      expect(box.value, isFalse);
    }
  });

  testWidgets('says this is step 1 of 5, choosing a topic', (tester) async {
    await openHousing(tester);

    expect(find.textContaining('Step 1 of 5'), findsOneWidget);
    expect(find.textContaining('Choose a topic'), findsWidgets);
  });

  testWidgets('cannot continue until a topic is ticked', (tester) async {
    await openHousing(tester);

    expect(continueEnabled(tester), isFalse);

    await tick(tester, 'Housing Crisis');

    expect(continueEnabled(tester), isTrue);
  });

  testWidgets('ticking records the choice and asks the server nothing', (tester) async {
    final container = await openHousing(tester);

    await tick(tester, 'Housing Crisis');
    await tick(tester, 'Homelessness');

    final draft = container.read(draftNotifierProvider);
    expect([for (final issue in draft.issues) issue.id], ['homelessness', 'housing-crisis']); // the list's order
    expect(draft.body, isEmpty);
    expect(api.composeRequests, isEmpty);
  });

  testWidgets('shows what has been chosen so far', (tester) async {
    await openHousing(tester);
    expect(find.textContaining('You have chosen'), findsNothing);

    await tick(tester, 'Housing Crisis');

    expect(find.text('You have chosen: Housing Crisis'), findsOneWidget);

    await tick(tester, 'Homelessness');

    expect(find.text('You have chosen: Homelessness, Housing Crisis'), findsOneWidget);
  });

  testWidgets('un-ticking the only topic means nothing to continue with again', (tester) async {
    final container = await openHousing(tester);
    await tick(tester, 'Housing Crisis');

    await tick(tester, 'Housing Crisis');

    expect(container.read(draftNotifierProvider).issues, isEmpty);
    expect(continueEnabled(tester), isFalse);
  });

  testWidgets('topics chosen in another category are kept, and listed here too', (tester) async {
    final container = await openApp(
      tester,
      api,
      path: '/craft/issues/category/housing',
      prepare: (draft) =>
          draft.setIssues(const [TopicSummary(id: 'triple-lock', title: 'Triple Lock', category: 'geopolitics')]),
    );

    expect(find.text('You have chosen: Triple Lock'), findsOneWidget);
    expect(continueEnabled(tester), isTrue); // something is chosen already

    await tick(tester, 'Homelessness');

    expect(find.text('You have chosen: Homelessness, Triple Lock'), findsOneWidget);
    expect(
      [for (final issue in container.read(draftNotifierProvider).issues) issue.id],
      ['homelessness', 'triple-lock'],
    );
  });

  testWidgets('a topic already chosen shows ticked when you come back to the category', (tester) async {
    await openApp(
      tester,
      api,
      path: '/craft/issues/category/housing',
      prepare: (draft) => draft.setIssues(const [homelessness]),
    );

    final box = tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, 'Homelessness'));
    expect(box.value, isTrue);
  });

  testWidgets('Continue opens the choice of letter style', (tester) async {
    await openHousing(tester);
    await tick(tester, 'Housing Crisis');

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a letter style'), findsWidgets);
  });

  testWidgets('a way back to the other categories', (tester) async {
    await openHousing(tester);

    await tester.tap(find.text('Choose from another category'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a category'), findsWidgets);
  });

  group('after text was written', () {
    Future<ProviderContainer> openWithEditedText(WidgetTester tester) async {
      final container = await openHousing(tester);
      final notifier = container.read(draftNotifierProvider.notifier)..setIssues(const [homelessness]);
      await notifier.chooseStyle(direct);
      notifier.setBody('My own words instead.');
      await tester.pumpAndSettle();
      return container;
    }

    testWidgets('changing the topics asks first, and Cancel keeps the edit and the choice', (tester) async {
      final container = await openWithEditedText(tester);

      await tick(tester, 'Housing Crisis');
      expect(find.text('This replaces your edits. Continue?'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Cancel')));
      await tester.pumpAndSettle();

      final draft = container.read(draftNotifierProvider);
      expect(draft.body, 'My own words instead.');
      expect([for (final issue in draft.issues) issue.id], ['homelessness']);
    });

    testWidgets('confirming changes the topics and takes the old text away to be written again', (tester) async {
      final container = await openWithEditedText(tester);

      await tick(tester, 'Housing Crisis');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Continue')));
      await tester.pumpAndSettle();

      final draft = container.read(draftNotifierProvider);
      expect([for (final issue in draft.issues) issue.id], ['homelessness', 'housing-crisis']);
      expect(draft.body, isEmpty);
      expect(draft.style, direct); // so the next screen offers it again
    });

    testWidgets('text that was not edited is simply replaced, with no question', (tester) async {
      final container = await openHousing(tester);
      final notifier = container.read(draftNotifierProvider.notifier)..setIssues(const [homelessness]);
      await notifier.chooseStyle(direct);
      await tester.pumpAndSettle();

      await tick(tester, 'Housing Crisis');

      expect(find.byType(AlertDialog), findsNothing);
      expect(container.read(draftNotifierProvider).issues, hasLength(2));
    });
  });

  testWidgets('a category that is not there says so and leads back to the list', (tester) async {
    await openApp(tester, api, path: '/craft/issues/category/made-up');

    expect(find.text('We could not find that category.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Choose a category'));
    await tester.pumpAndSettle();

    expect(find.text('Housing'), findsOneWidget);
  });

  testWidgets('if the topics cannot be loaded, says so and can try again', (tester) async {
    api.topicsFail = true;
    await openHousing(tester);

    expect(find.textContaining('Could not load'), findsOneWidget);

    api.topicsFail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Housing Crisis'), findsOneWidget);
  });
}
