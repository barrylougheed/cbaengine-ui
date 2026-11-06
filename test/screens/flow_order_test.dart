import 'package:app/providers/draft/draft_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// The order of the steps: the email first (issues and proposals, your own
/// words, or a campaign), then council, then area, then review. A raw address
/// cannot skip ahead, and each complete journey ends on Review.
void main() {
  late FakeApi api;

  setUp(() => api = FakeApi());

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> continueOn(WidgetTester tester) => tap(tester, find.widgetWithText(FilledButton, 'Continue'));

  group('a raw address cannot skip a step', () {
    testWidgets('the council step needs a finished email first', (tester) async {
      await openApp(tester, api, path: '/council');

      expect(find.text('Craft an email'), findsOneWidget); // back on Home
      expect(find.textContaining('Select your council'), findsNothing);
    });

    testWidgets('the area step needs a finished email first', (tester) async {
      await openApp(tester, api, path: '/council/fingal-county-council/lea');

      expect(find.text('Craft an email'), findsOneWidget);
    });

    testWidgets('Find your area needs a finished email first', (tester) async {
      await openApp(tester, api, path: '/find-area');

      expect(find.text('Craft an email'), findsOneWidget);
    });

    testWidgets('Review needs a finished email first', (tester) async {
      await openApp(tester, api, path: '/review');

      expect(find.text('Craft an email'), findsOneWidget);
    });

    testWidgets('Review needs an area too: a finished email without one is sent to choose a council', (tester) async {
      await openApp(tester, api, prepare: finishedOwnWordsEmail, path: '/review');

      expect(find.textContaining('Select your council'), findsOneWidget);
    });

    testWidgets('the write-your-own step is only for an email in your own words', (tester) async {
      await openApp(tester, api, path: '/craft/own'); // the draft is about issues by default

      expect(find.text('Select issues'), findsOneWidget); // sent back to the choice
    });

    testWidgets('the campaign email step needs a campaign chosen', (tester) async {
      await openApp(tester, api, path: '/campaigns/email');

      expect(find.text('Choose a campaign to back.'), findsOneWidget); // back on the list
    });
  });

  group('the journey ends on Review', () {
    testWidgets('in your own words: email -> council -> area -> review', (tester) async {
      await openApp(tester, api);

      await tap(tester, find.text('Craft an email'));
      await tap(tester, find.text('Write my own email'));
      expect(find.textContaining('Step 1 of 5'), findsOneWidget);
      await tester.enterText(find.byType(TextField).at(0), 'Sam Resident');
      await tester.enterText(find.byType(TextField).at(1), 'Bins on Main Street');
      await tester.enterText(find.byType(TextField).at(2), 'The bins have not been collected.');
      await tester.pumpAndSettle();
      await continueOn(tester);

      expect(find.textContaining('Step 2 of 5'), findsOneWidget);
      await tap(tester, find.text('Fingal County Council'));
      expect(find.textContaining('Step 3 of 5'), findsOneWidget);
      await tap(tester, find.text('Balbriggan'));

      expect(find.textContaining('Step 4 of 5'), findsOneWidget);
      expect(find.text('Bins on Main Street'), findsOneWidget);
      expect(find.text('The bins have not been collected.'), findsOneWidget);
      expect(find.text('Written by you'), findsOneWidget);
      expect(find.text('This will be sent to 2 councillors'), findsOneWidget);
      expect(find.text('Ann One'), findsOneWidget);
    });

    testWidgets('about issues: pick, tick, name -> council -> area -> review, with the footer', (tester) async {
      await openApp(tester, api);

      await tap(tester, find.text('Craft an email'));
      await tap(tester, find.text('Select issues'));
      await tap(tester, find.text('Housing Crisis'));
      await tap(tester, find.text('a public register to monitor house bidding'));
      await tester.enterText(find.byType(TextField).at(0), 'Sam Resident');
      await tester.pumpAndSettle();
      await continueOn(tester);
      await tap(tester, find.text('Fingal County Council'));
      await tap(tester, find.text('Castleknock'));

      expect(find.textContaining('Step 4 of 5'), findsOneWidget);
      expect(find.text('Where do you stand on housing-crisis?'), findsOneWidget);
      expect(find.text('Issues: Housing Crisis'), findsOneWidget);
      expect(find.text('Started from a topic template.'), findsOneWidget);
      expect(find.text('This will be sent to 1 councillor'), findsOneWidget);
    });

    testWidgets('for a campaign: pick -> name -> council -> area -> review, with the campaign footer', (tester) async {
      await openApp(tester, api);

      await tap(tester, find.text('Campaigns'));
      await tap(tester, find.text("Save Stephen's Green"));
      await tester.enterText(find.byType(TextField).at(0), 'Sam Resident');
      await tester.pumpAndSettle();
      await continueOn(tester);
      await tap(tester, find.text('Fingal County Council'));
      await tap(tester, find.text('Balbriggan'));

      expect(find.textContaining('Step 4 of 5'), findsOneWidget);
      expect(find.text('Subject for save-stephens-green'), findsOneWidget);
      expect(find.text("Campaign: Save Stephen's Green"), findsOneWidget);
      expect(find.text("Sent as part of the 'Save Stephen's Green' campaign."), findsOneWidget);
    });

    testWidgets('going back from Review to the email keeps what was written', (tester) async {
      final container = await openApp(tester, api);
      await tap(tester, find.text('Craft an email'));
      await tap(tester, find.text('Write my own email'));
      await tester.enterText(find.byType(TextField).at(0), 'Sam Resident');
      await tester.enterText(find.byType(TextField).at(1), 'Bins on Main Street');
      await tester.enterText(find.byType(TextField).at(2), 'The bins have not been collected.');
      await tester.pumpAndSettle();
      await continueOn(tester);
      await tap(tester, find.text('Fingal County Council'));
      await tap(tester, find.text('Balbriggan'));
      expect(find.textContaining('Step 4 of 5'), findsOneWidget);

      // Review -> area -> council -> the email.
      for (var step = 0; step < 3; step++) {
        tester.state<NavigatorState>(find.byType(Navigator).last).pop();
        await tester.pumpAndSettle();
      }

      expect(find.textContaining('Step 1 of 5'), findsOneWidget);
      expect(container.read(draftNotifierProvider).body, 'The bins have not been collected.');
      expect(tester.widget<TextField>(find.byType(TextField).at(2)).controller!.text, 'The bins have not been collected.');
    });
  });
}
