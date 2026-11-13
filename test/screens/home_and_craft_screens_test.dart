import 'package:app/models/message_intent.dart';
import 'package:app/providers/draft/draft_notifier.dart';
import 'package:app/screens/privacy_screen.dart';
import 'package:app/theme/app_theme.dart';
import 'package:app/widgets/app_footer.dart';
import 'package:app/widgets/content_width.dart';
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
    // Sets the window to a phone or a desktop width after the app has opened.
    Future<void> resize(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 2400);
      await tester.pumpAndSettle();
    }

    testWidgets('opens with a headline and the tagline, in a deep olive hero', (tester) async {
      await openApp(tester, api);

      expect(find.text('Email your local councillors in minutes'), findsOneWidget);
      expect(find.text('Hold yourself accountable for holding power accountable.'), findsOneWidget);
      expect(find.text('What would you like to do?'), findsOneWidget);
      final hero = tester.widget<ColoredBox>(find.byKey(const Key('home-hero')));
      expect(hero.color, AppColors.deepOlive);
    });

    testWidgets('offers crafting an email and campaigns, and shows the campaign link as coming soon', (tester) async {
      await openApp(tester, api);

      expect(find.text('Craft an email'), findsOneWidget);
      expect(find.text('Campaigns'), findsOneWidget);
      expect(find.text('Create a campaign link'), findsOneWidget);
      expect(find.text('Coming soon'), findsOneWidget);
      expect(find.text('Contact your councillors'), findsNothing); // the old single card is gone
    });

    testWidgets('the campaign link card cannot be opened yet, and the other two can', (tester) async {
      await openApp(tester, api);

      InkWell cardFor(String title) =>
          tester.widget<InkWell>(find.ancestor(of: find.text(title), matching: find.byType(InkWell)).first);

      expect(cardFor('Create a campaign link').onTap, isNull);
      expect(cardFor('Craft an email').onTap, isNotNull);
      expect(cardFor('Campaigns').onTap, isNotNull);
    });

    testWidgets('puts the three options side by side on a desktop and one under another on a phone', (tester) async {
      await openApp(tester, api);

      await resize(tester, 1100);
      expect(tester.getTopLeft(find.text('Campaigns')).dy, tester.getTopLeft(find.text('Craft an email')).dy);
      expect(
        tester.getTopLeft(find.text('Campaigns')).dx,
        greaterThan(tester.getTopLeft(find.text('Craft an email')).dx),
      );

      await resize(tester, 390);
      expect(
        tester.getTopLeft(find.text('Campaigns')).dy,
        greaterThan(tester.getTopLeft(find.text('Craft an email')).dy),
      );
      expect(tester.takeException(), isNull);
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
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('says up front which accounts can send', (tester) async {
      await openApp(tester, api);

      expect(find.text("You'll need a Gmail, Outlook or Hotmail account to send."), findsOneWidget);
    });

    testWidgets('shows how many councillors, councils and areas you can write to, as large numbers', (tester) async {
      await openApp(tester, api);

      // 5 + 63 councillors in 2 councils, and 2 + 11 areas (see FakeApi). The
      // step numbers 1 to 3 are elsewhere on the page, so look only in the strip.
      Finder inStrip(String text) =>
          find.descendant(of: find.byKey(const Key('home-stats')), matching: find.text(text));

      expect(inStrip('68'), findsOneWidget);
      expect(inStrip('councillors'), findsOneWidget);
      expect(inStrip('2'), findsOneWidget);
      expect(inStrip('councils'), findsOneWidget);
      expect(inStrip('13'), findsOneWidget);
      expect(inStrip('local areas'), findsOneWidget);
    });

    testWidgets('still works, without the totals, if the councils cannot be loaded', (tester) async {
      api.councilsFail = true;
      await openApp(tester, api);

      expect(find.text('How it works'), findsOneWidget);
      expect(find.byKey(const Key('home-stats')), findsNothing);
      expect(find.text('councillors'), findsNothing);
      expect(find.text('local areas'), findsNothing);
    });

    testWidgets('ends with the footer: the independence statement and the privacy notice', (tester) async {
      await openApp(tester, api);

      expect(find.text('An independent service, not affiliated with the Government of Ireland.'), findsOneWidget);
      expect(find.text('Privacy notice'), findsOneWidget);

      await tester.ensureVisible(find.text('Privacy notice'));
      await tester.tap(find.text('Privacy notice'));
      await tester.pumpAndSettle();

      expect(find.byType(PrivacyScreen), findsOneWidget);
    });

    testWidgets('keeps the footer at the bottom of a very tall window', (tester) async {
      await openApp(tester, api);
      tester.view.physicalSize = const Size(1100, 6000);
      await tester.pumpAndSettle();

      final footer = tester.getRect(find.byType(AppFooter));
      expect(footer.bottom, 6000);
    });

    testWidgets('has no placeholder social icons until real accounts exist', (tester) async {
      await openApp(tester, api);

      expect(find.byTooltip('Instagram — coming soon'), findsNothing);
      expect(find.byTooltip('YouTube — coming soon'), findsNothing);
    });

    testWidgets('on a wide screen the content keeps to its maximum width', (tester) async {
      await openApp(tester, api);
      await resize(tester, 1800);

      final strip = tester.getRect(find.byKey(const Key('home-stats')));
      expect(strip.width, lessThanOrEqualTo(ContentWidth.wide));
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

      expect(find.text('Choose the issues you care about.'), findsOneWidget);
      expect(find.text('Say what you think in your own words.'), findsOneWidget);
    });

    testWidgets('Select issues starts an email about issues and opens the choice of category', (tester) async {
      final container = await openApp(tester, api, path: '/craft');

      await tester.tap(find.text('Select issues'));
      await tester.pumpAndSettle();

      expect(container.read(draftNotifierProvider).intent, MessageIntent.issues);
      expect(find.text('Choose a category'), findsOneWidget);
      expect(find.text('Housing'), findsOneWidget);
      expect(find.text('Housing Crisis'), findsNothing); // the topics come after the category
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
