import 'package:app/models/message_intent.dart';
import 'package:app/models/style_summary.dart';
import 'package:app/models/topic_summary.dart';
import 'package:app/providers/draft/draft_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// The first screen of an email about issues: choose a category (Housing,
/// Geopolitics...). The server sends only categories that have an issue ready,
/// in the owner's order. Nothing here needs an area, and nothing is asked of the
/// server beyond the list.
void main() {
  late FakeApi api;
  const direct = StyleSummary(id: 'direct', title: 'Direct', description: 'Respectful and to the point.');

  setUp(() => api = FakeApi());

  Future<ProviderContainer> openCategories(WidgetTester tester, {void Function(DraftNotifier)? prepare}) =>
      openApp(tester, api, path: '/craft/issues', prepare: prepare);

  /// True when [first] is read before [second]: on an earlier row, or on the
  /// same row and further left (the order of a grid).
  bool readsBefore(WidgetTester tester, String first, String second) {
    final a = tester.getTopLeft(find.text(first));
    final b = tester.getTopLeft(find.text(second));
    return a.dy < b.dy - 1 || ((a.dy - b.dy).abs() <= 1 && a.dx < b.dx);
  }

  testWidgets('offers each category the server sends, in its order, saying how many topics are in it', (tester) async {
    await openCategories(tester);

    expect(find.text('Choose a category'), findsOneWidget);
    expect(find.text('Housing'), findsOneWidget);
    expect(find.text('Geopolitics'), findsOneWidget);
    expect(find.text('2 topics'), findsOneWidget); // Homelessness and Housing Crisis
    expect(find.text('1 topic'), findsOneWidget); // Triple Lock
    expect(readsBefore(tester, 'Housing', 'Geopolitics'), isTrue);
  });

  group('as a grid', () {
    /// Categories whose titles differ in length, with a topic each so none is empty.
    void severalCategories() {
      const titles = {
        'housing': 'Housing',
        'homelessness': 'Homelessness',
        'healthcare': 'Healthcare',
        'community-issues': 'Community issues',
        'employment': 'Employment',
      };
      api
        ..categories = [
          for (final entry in titles.entries) {'id': entry.key, 'title': entry.value},
        ]
        ..issues = [
          for (final entry in titles.entries)
            {'id': 'topic-${entry.key}', 'title': 'Topic ${entry.value}', 'category': entry.key},
        ];
    }

    /// The card a category's title is in.
    Rect tile(WidgetTester tester, String title) =>
        tester.getRect(find.ancestor(of: find.text(title), matching: find.byType(Card)).first);

    Future<void> resize(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 2400);
      await tester.pumpAndSettle();
    }

    testWidgets('puts the categories side by side, three to a row where there is room', (tester) async {
      severalCategories();
      await openCategories(tester);
      await resize(tester, 900);

      final row = [
        for (final title in ['Housing', 'Homelessness', 'Healthcare']) tile(tester, title),
      ];
      expect(row[0].top, row[1].top);
      expect(row[1].top, row[2].top);
      expect(row[0].left, lessThan(row[1].left));
      expect(row[1].left, lessThan(row[2].left));
      // The fourth starts the next row, under the first.
      final next = tile(tester, 'Community issues');
      expect(next.top, greaterThan(row[0].bottom - 1));
      expect(next.left, row[0].left);
    });

    testWidgets('puts two to a row on a phone', (tester) async {
      severalCategories();
      await openCategories(tester);
      await resize(tester, 390);

      final first = tile(tester, 'Housing');
      final second = tile(tester, 'Homelessness');
      final third = tile(tester, 'Healthcare');
      expect(first.top, second.top);
      expect(first.left, lessThan(second.left));
      expect(third.top, greaterThan(first.bottom - 1)); // the third starts the next row
      expect(third.left, first.left);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps the order of the server reading across, then down', (tester) async {
      severalCategories();
      await openCategories(tester);
      await resize(tester, 390);

      final titles = ['Housing', 'Homelessness', 'Healthcare', 'Community issues', 'Employment'];
      for (var i = 0; i < titles.length - 1; i++) {
        expect(readsBefore(tester, titles[i], titles[i + 1]), isTrue, reason: '${titles[i]} before ${titles[i + 1]}');
      }
    });

    testWidgets('makes the tiles in a row equally tall, whatever their titles', (tester) async {
      severalCategories();
      await openCategories(tester);
      await resize(tester, 390); // two across: Healthcare and Community issues share the second row

      // "Community issues" wraps onto two lines here and "Employment" (alone on the last row) does not...
      expect(tile(tester, 'Community issues').height, greaterThan(tile(tester, 'Employment').height));
      // ...so its row-mate is stretched to match it, rather than left shorter.
      expect(tile(tester, 'Healthcare').height, tile(tester, 'Community issues').height);
      expect(tile(tester, 'Housing').height, tile(tester, 'Homelessness').height);
    });

    testWidgets('gives a lone tile on the last row the same width as the others, not the whole row', (tester) async {
      severalCategories();
      await openCategories(tester);
      await resize(tester, 390);

      expect(tile(tester, 'Employment').width, closeTo(tile(tester, 'Housing').width, 0.5));
    });

    testWidgets('keeps the tiles inside the reading column and the screen', (tester) async {
      severalCategories();
      await openCategories(tester);

      await resize(tester, 1600);
      for (final title in ['Housing', 'Healthcare', 'Employment']) {
        final rect = tile(tester, title);
        expect(rect.left, greaterThanOrEqualTo((1600 - 720) / 2 - 0.5), reason: title);
        expect(rect.right, lessThanOrEqualTo(1600 - (1600 - 720) / 2 + 0.5), reason: title);
      }

      await resize(tester, 360);
      for (final title in ['Housing', 'Homelessness', 'Employment']) {
        final rect = tile(tester, title);
        expect(rect.left, greaterThanOrEqualTo(0), reason: title);
        expect(rect.right, lessThanOrEqualTo(360), reason: title);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('every tile is still a card you can press, and says how many topics it holds', (tester) async {
      severalCategories();
      await openCategories(tester);

      expect(find.text('1 topic'), findsNWidgets(5));

      await tester.tap(find.text('Healthcare'));
      await tester.pumpAndSettle();

      expect(find.text('Topic Healthcare'), findsOneWidget);
      expect(find.text('Topic Housing'), findsNothing);
    });

    testWidgets('a single category is one tile, the same size as in a full row', (tester) async {
      severalCategories();
      await openCategories(tester);
      await resize(tester, 900);
      final inFullRow = tile(tester, 'Housing').width;

      api
        ..categories = [
          {'id': 'housing', 'title': 'Housing'},
        ]
        ..issues = [
          {'id': 'topic-housing', 'title': 'Topic Housing', 'category': 'housing'},
        ];
      await openCategories(tester);
      await resize(tester, 900);

      expect(tile(tester, 'Housing').width, closeTo(inFullRow, 0.5));
    });
  });

  testWidgets('Homelessness can be a category of its own, beside Housing, with an icon of its own', (tester) async {
    api
      ..categories = [
        {'id': 'housing', 'title': 'Housing'},
        {'id': 'homelessness', 'title': 'Homelessness'},
      ]
      ..issues = [
        {'id': 'homelessness', 'title': 'Homelessness', 'category': 'homelessness'},
        {'id': 'housing-crisis', 'title': 'Housing Crisis', 'category': 'housing'},
      ];
    await openCategories(tester);

    expect(find.text('Housing'), findsOneWidget);
    expect(find.text('Homelessness'), findsOneWidget);
    expect(find.byIcon(Icons.night_shelter_outlined), findsOneWidget);
    expect(find.byIcon(Icons.label_outline), findsNothing); // not the plain tag a category without an icon gets
    expect(find.text('1 topic'), findsNWidgets(2)); // one in each

    await tester.tap(find.text('Homelessness'));
    await tester.pumpAndSettle();

    expect(find.byType(CheckboxListTile), findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Homelessness'), findsOneWidget);
  });

  testWidgets('says this is step 1 of 5', (tester) async {
    await openCategories(tester);

    expect(find.textContaining('Step 1 of 5'), findsOneWidget);
    expect(find.textContaining('Choose a category'), findsWidgets);
  });

  testWidgets('shows no topics, no text and nothing to continue with until something is chosen', (tester) async {
    await openCategories(tester);

    expect(find.text('Homelessness'), findsNothing); // the topics are on the next screen
    expect(find.byType(TextField), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Continue'), findsNothing);
    expect(api.composeRequests, isEmpty);
  });

  testWidgets('choosing a category opens the topics in it, and only those', (tester) async {
    await openCategories(tester);

    await tester.tap(find.text('Housing'));
    await tester.pumpAndSettle();

    expect(find.text('Homelessness'), findsOneWidget);
    expect(find.text('Housing Crisis'), findsOneWidget);
    expect(find.text('Triple Lock'), findsNothing);
  });

  testWidgets('topics already chosen are listed, with a way to carry on to the style', (tester) async {
    await openCategories(
      tester,
      prepare: (draft) => draft.setIssues(const [
        TopicSummary(id: 'homelessness', title: 'Homelessness', category: 'housing'),
        TopicSummary(id: 'triple-lock', title: 'Triple Lock', category: 'geopolitics'),
      ]),
    );

    expect(find.text('You have chosen: Homelessness, Triple Lock'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Continue'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a letter style'), findsWidgets);
  });

  testWidgets('points anyone who wants to say something different to writing their own email', (tester) async {
    final container = await openCategories(tester);

    expect(find.text('Want to say something different? Write your own email.'), findsOneWidget);
    await tester.tap(find.text('Want to say something different? Write your own email.'));
    await tester.pumpAndSettle();

    expect(container.read(draftNotifierProvider).intent, MessageIntent.own);
    expect(find.widgetWithText(TextField, 'Subject'), findsOneWidget);
  });

  testWidgets('switching to your own email after editing asks first, and Cancel stays', (tester) async {
    final container = await openCategories(tester);
    final notifier = container.read(draftNotifierProvider.notifier);
    notifier.setIssues(const [TopicSummary(id: 'homelessness', title: 'Homelessness', category: 'housing')]);
    await notifier.chooseStyle(direct);
    notifier.setBody('My own words instead.');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Want to say something different? Write your own email.'));
    await tester.pumpAndSettle();
    expect(find.text('This clears what you have written. Continue?'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Cancel')));
    await tester.pumpAndSettle();

    expect(container.read(draftNotifierProvider).intent, MessageIntent.issues);
    expect(container.read(draftNotifierProvider).body, 'My own words instead.');
  });

  group('when there is nothing to show', () {
    testWidgets('with no issues ready, says so and offers writing your own', (tester) async {
      api
        ..issues = []
        ..categories = [];
      await openCategories(tester);

      expect(find.text('No issues are available yet. You can write your own email instead.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Write my own email'), findsOneWidget);
    });

    testWidgets('Write my own email there switches to writing your own', (tester) async {
      api
        ..issues = []
        ..categories = [];
      final container = await openCategories(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Write my own email'));
      await tester.pumpAndSettle();

      expect(container.read(draftNotifierProvider).intent, MessageIntent.own);
      expect(find.widgetWithText(TextField, 'Subject'), findsOneWidget);
    });

    testWidgets('if the categories cannot be loaded, says so and can try again', (tester) async {
      api.topicsFail = true;
      await openCategories(tester);

      expect(find.textContaining('Could not load'), findsOneWidget);

      api.topicsFail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Housing'), findsOneWidget);
    });
  });
}
