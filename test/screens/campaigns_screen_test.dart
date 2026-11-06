import 'package:app/models/message_intent.dart';
import 'package:app/providers/draft/draft_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// Backing a campaign: pick one from the list, read and edit the email the
/// server writes for it, add your name, then choose your area like any other email.
void main() {
  late FakeApi api;

  setUp(() => api = FakeApi());

  TextField field(WidgetTester tester, int index) => tester.widget<TextField>(find.byType(TextField).at(index));
  String text(WidgetTester tester, int index) => field(tester, index).controller!.text;
  bool continueEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue')).onPressed != null;

  Future<void> chooseGreen(WidgetTester tester) async {
    await tester.tap(find.text("Save Stephen's Green"));
    await tester.pumpAndSettle();
  }

  group('the list', () {
    testWidgets('shows each campaign with its title and summary', (tester) async {
      await openApp(tester, api, path: '/campaigns');

      expect(find.text("Save Stephen's Green"), findsOneWidget);
      expect(find.text('Keep the Green open to everyone.'), findsOneWidget);
      expect(find.text('Give us the night'), findsOneWidget);
      expect(find.text('A livelier night-time city.'), findsOneWidget);
    });

    testWidgets('offers a "Learn more" link only for a campaign that has one', (tester) async {
      await openApp(tester, api, path: '/campaigns');

      expect(find.text('Learn more'), findsOneWidget);
    });

    testWidgets('says what to do, and that the email goes to your own area councillors', (tester) async {
      await openApp(tester, api, path: '/campaigns');

      expect(find.text('Choose a campaign to back.'), findsOneWidget);
      expect(find.textContaining('goes to your own area councillors'), findsOneWidget);
    });

    testWidgets('with no campaigns open yet, says so', (tester) async {
      api.campaigns = [];
      await openApp(tester, api, path: '/campaigns');

      expect(find.text('No campaigns are open yet.'), findsOneWidget);
    });

    testWidgets('if the campaigns cannot be loaded, says so and can try again', (tester) async {
      api.campaignsFail = true;
      await openApp(tester, api, path: '/campaigns');

      expect(find.textContaining('Could not load'), findsOneWidget);

      api.campaignsFail = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text("Save Stephen's Green"), findsOneWidget);
    });
  });

  group('choosing a campaign', () {
    testWidgets('fetches its email and opens it, with the campaign footer and no area asked for', (tester) async {
      final container = await openApp(tester, api, path: '/campaigns');

      await chooseGreen(tester);

      expect(api.campaignRequests.single, {'id': 'save-stephens-green', 'variants': <String, String>{}});
      expect(container.read(draftNotifierProvider).intent, MessageIntent.campaign);
      expect(container.read(draftNotifierProvider).campaign?.id, 'save-stephens-green');
      // name, subject, message
      expect(text(tester, 1), 'Subject for save-stephens-green');
      expect(text(tester, 2), 'Body for save-stephens-green.');
      expect(find.textContaining("Sent as part of the 'Save Stephen's Green' campaign."), findsOneWidget);
    });

    testWidgets('shows which campaign it is above the email', (tester) async {
      await openApp(tester, api, path: '/campaigns');

      await chooseGreen(tester);

      expect(find.text("Save Stephen's Green"), findsWidgets);
      expect(find.text('Keep the Green open to everyone.'), findsOneWidget);
    });

    testWidgets('the name is still needed before continuing', (tester) async {
      await openApp(tester, api, path: '/campaigns');
      await chooseGreen(tester);
      expect(continueEnabled(tester), isFalse);

      await tester.enterText(find.byType(TextField).at(0), 'Sam Resident');
      await tester.pumpAndSettle();

      expect(continueEnabled(tester), isTrue);
    });

    testWidgets('the email can be edited, and text left in double square brackets blocks continuing', (tester) async {
      await openApp(tester, api, path: '/campaigns');
      await chooseGreen(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Sam Resident');
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(2), 'Body [[context: fill me in]]');
      await tester.pumpAndSettle();

      expect(find.textContaining('double square brackets'), findsOneWidget);
      expect(continueEnabled(tester), isFalse);
    });

    testWidgets('Continue opens the council step', (tester) async {
      await openApp(tester, api, path: '/campaigns');
      await chooseGreen(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Sam Resident');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Select your council'), findsOneWidget);
    });

    testWidgets('says this is step 1 of 5', (tester) async {
      await openApp(tester, api, path: '/campaigns');

      await chooseGreen(tester);

      expect(find.textContaining('Step 1 of 5'), findsOneWidget);
    });

    testWidgets('if the email cannot be loaded, says so and stays on the list', (tester) async {
      api.campaignComposeFails = true;
      final container = await openApp(tester, api, path: '/campaigns');

      await chooseGreen(tester);

      expect(find.text('Campaign not found.'), findsOneWidget);
      expect(find.text('Choose a campaign to back.'), findsOneWidget); // still on the list
      expect(container.read(draftNotifierProvider).campaign, isNull);
    });
  });

  group('changing your mind', () {
    testWidgets('going back and choosing another campaign after an edit asks first, and Cancel keeps the edit', (
      tester,
    ) async {
      final container = await openApp(tester, api, path: '/campaigns');
      await chooseGreen(tester);
      await tester.enterText(find.byType(TextField).at(2), 'My own words instead.');
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Give us the night'));
      await tester.pumpAndSettle();
      expect(find.text('This replaces your edits. Continue?'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Cancel')));
      await tester.pumpAndSettle();

      expect(container.read(draftNotifierProvider).campaign?.id, 'save-stephens-green');
      expect(container.read(draftNotifierProvider).body, 'My own words instead.');
    });

    testWidgets('confirming replaces the edit with the other campaign', (tester) async {
      final container = await openApp(tester, api, path: '/campaigns');
      await chooseGreen(tester);
      await tester.enterText(find.byType(TextField).at(2), 'My own words instead.');
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Give us the night'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Continue')));
      await tester.pumpAndSettle();

      expect(container.read(draftNotifierProvider).campaign?.id, 'give-us-the-night');
      expect(text(tester, 2), 'Body for give-us-the-night.');
    });

    testWidgets('choosing the same campaign again goes straight back to your email, edits and all', (tester) async {
      final container = await openApp(tester, api, path: '/campaigns');
      await chooseGreen(tester);
      await tester.enterText(find.byType(TextField).at(2), 'My own words instead.');
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
      await tester.pumpAndSettle();

      await chooseGreen(tester);

      expect(find.text('This replaces your edits. Continue?'), findsNothing);
      expect(api.campaignRequests, hasLength(1)); // nothing more was asked of the server
      expect(container.read(draftNotifierProvider).body, 'My own words instead.');
      expect(text(tester, 2), 'My own words instead.');
    });
  });
}
