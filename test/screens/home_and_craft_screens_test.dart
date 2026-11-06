import 'package:app/models/message_intent.dart';
import 'package:app/providers/draft/draft_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// Where a resident starts: Home (craft an email, back a campaign, and the
/// campaign link that is still to come), and the choice between picking issues
/// and writing their own.
void main() {
  late FakeApi api;

  setUp(() => api = FakeApi());

  group('home', () {
    testWidgets('offers crafting an email and campaigns, and shows the campaign link as coming soon', (tester) async {
      await openApp(tester, api);

      expect(find.text('Craft an email'), findsOneWidget);
      expect(find.text('Campaigns'), findsOneWidget);
      expect(find.text('Create a campaign link'), findsOneWidget);
      expect(find.text('Coming soon'), findsOneWidget);
      expect(find.text('Contact your councillors'), findsNothing); // the old single card is gone
    });

    testWidgets('the campaign link card cannot be opened yet', (tester) async {
      await openApp(tester, api);

      final tile = tester.widget<ListTile>(find.widgetWithText(ListTile, 'Create a campaign link'));

      expect(tile.enabled, isFalse);
    });

    testWidgets('says up front that one email can be sent a day', (tester) async {
      await openApp(tester, api);

      expect(find.text('You can send one email a day.'), findsOneWidget);
    });

    testWidgets('explains how it works, in three steps', (tester) async {
      await openApp(tester, api);

      expect(find.text('How it works'), findsOneWidget);
      expect(find.text('Craft an email, or back a campaign.'), findsOneWidget);
      expect(find.text('Choose your council and area, then review your message and who it goes to.'), findsOneWidget);
      expect(
        find.text(
          'Connect your Gmail or Outlook account. Your message is sent straight away, from your own account, with a copy to you.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('says up front which accounts can send', (tester) async {
      await openApp(tester, api);

      expect(find.text("You'll need a Gmail, Outlook or Hotmail account to send."), findsOneWidget);
    });

    testWidgets('says how many councillors and councils you can write to', (tester) async {
      await openApp(tester, api);

      expect(find.text('Write to any of 68 councillors across 2 councils.'), findsOneWidget);
    });

    testWidgets('still works, without the total, if the councils cannot be loaded', (tester) async {
      api.councilsFail = true;
      await openApp(tester, api);

      expect(find.text('How it works'), findsOneWidget);
      expect(find.textContaining('Write to any of'), findsNothing);
    });

    testWidgets('Craft an email opens the choice between issues and your own words', (tester) async {
      await openApp(tester, api);

      await tester.tap(find.text('Craft an email'));
      await tester.pumpAndSettle();

      expect(find.text('Select issues'), findsOneWidget);
      expect(find.text('Write my own email'), findsOneWidget);
    });

    testWidgets('Campaigns opens the list of campaigns', (tester) async {
      await openApp(tester, api);

      await tester.tap(find.text('Campaigns'));
      await tester.pumpAndSettle();

      expect(find.text("Save Stephen's Green"), findsOneWidget);
    });
  });

  group('craft an email', () {
    testWidgets('says what each choice is for', (tester) async {
      await openApp(tester, api, path: '/craft');

      expect(find.text('Choose issues you care about and tick the proposals you support.'), findsOneWidget);
      expect(find.text('Say what you think in your own words.'), findsOneWidget);
    });

    testWidgets('Select issues starts an email about issues and opens the issues step', (tester) async {
      final container = await openApp(tester, api, path: '/craft');

      await tester.tap(find.text('Select issues'));
      await tester.pumpAndSettle();

      expect(container.read(draftNotifierProvider).intent, MessageIntent.issues);
      expect(find.text('Housing Crisis'), findsOneWidget);
    });

    testWidgets('Write my own email starts an email in your own words and opens that step', (tester) async {
      final container = await openApp(tester, api, path: '/craft');

      await tester.tap(find.text('Write my own email'));
      await tester.pumpAndSettle();

      expect(container.read(draftNotifierProvider).intent, MessageIntent.own);
      expect(find.widgetWithText(TextField, 'Subject'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Message'), findsOneWidget);
    });

    testWidgets('going back and choosing the other kind of email asks before throwing away what you wrote', (
      tester,
    ) async {
      final container = await openApp(tester, api, path: '/craft');
      await tester.tap(find.text('Write my own email'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Message'), 'Something I wrote.');
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Select issues'));
      await tester.pumpAndSettle();
      expect(find.text('This clears what you have written. Continue?'), findsOneWidget);
      expect(container.read(draftNotifierProvider).intent, MessageIntent.own); // nothing changed yet
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Continue')));
      await tester.pumpAndSettle();

      expect(container.read(draftNotifierProvider).intent, MessageIntent.issues);
      expect(container.read(draftNotifierProvider).body, isEmpty);
    });

    testWidgets('Cancel keeps what you wrote', (tester) async {
      final container = await openApp(tester, api, path: '/craft');
      await tester.tap(find.text('Write my own email'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Message'), 'Something I wrote.');
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator).last).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Select issues'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Cancel')));
      await tester.pumpAndSettle();

      expect(container.read(draftNotifierProvider).intent, MessageIntent.own);
      expect(container.read(draftNotifierProvider).body, 'Something I wrote.');
    });
  });
}
