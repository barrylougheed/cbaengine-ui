import 'package:app/models/council.dart';
import 'package:app/models/councillor_preview.dart';
import 'package:app/models/lea.dart';
import 'package:app/models/message_intent.dart';
import 'package:app/models/topic_summary.dart';
import 'package:app/providers/draft/draft_notifier.dart';
import 'package:app/screens/privacy_screen.dart';
import 'package:app/widgets/app_footer.dart';
import 'package:app/widgets/content_width.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// Every step of the flow shares one layout: the content sits in a centred
/// reading column (at most [ContentWidth.form] wide) however wide the window is,
/// and shrinks to the screen with a 16px margin on a phone. This opens each
/// screen in a very wide and a very narrow window and checks that one
/// representative piece of its content is where it should be.
///
/// Every one of them also ends with the footer (the independence statement and
/// the way to the privacy notice), as Home does.
///
/// Home has its own, wider layout and is checked in its own tests.
void main() {
  late FakeApi api;

  setUp(() => api = FakeApi());

  /// The draft a resident has before choosing the council: their own email, written.
  void emailWritten(DraftNotifier draft) {
    draft
      ..setIntent(MessageIntent.own)
      ..setSenderName('Sam Resident')
      ..setSubject('Subject')
      ..setBody('Body');
  }

  /// ...and after choosing the area, ready to review.
  void areaChosen(DraftNotifier draft) {
    emailWritten(draft);
    draft
      ..selectCouncil(const Council(id: 'fingal-county-council', name: 'Fingal County Council'))
      ..selectLea(
        const Lea(
          id: 'swords',
          name: 'Swords',
          council: 'Fingal County Council',
          councillors: [CouncillorPreview(name: 'A Councillor', party: 'Independent')],
        ),
      );
  }

  Finder cardWith(String text) => find.ancestor(of: find.text(text), matching: find.byType(Card)).first;

  final screens =
      <
        ({
          String name,
          String path,
          void Function(DraftNotifier draft)? prepare,
          Future<void> Function(WidgetTester tester)? after,
          Finder Function() content,
        })
      >[
        (name: 'Craft an email', path: '/craft', prepare: null, after: null, content: () => cardWith('Select issues')),
        (
          name: 'Choose a category',
          path: '/craft/issues',
          prepare: null,
          after: null,
          content: () => cardWith('Housing'),
        ),
        (
          name: 'Choose a topic',
          path: '/craft/issues/category/housing',
          prepare: null,
          after: null,
          content: () => find.byType(Card).first,
        ),
        (
          name: 'Choose a letter style',
          path: '/craft/issues/style',
          // The style screen needs topics chosen (the router sends a visit without any back).
          prepare: (draft) =>
              draft.setIssues(const [TopicSummary(id: 'homelessness', title: 'Homelessness', category: 'housing')]),
          after: null,
          content: () => cardWith('Direct'),
        ),
        (
          name: 'Write an issues email',
          path: '/craft/issues',
          prepare: null,
          // Walked to as a resident does: the editor needs text the server wrote.
          after: (tester) => walkToTheIssueEmail(tester),
          content: () => find.widgetWithText(TextField, 'Subject'),
        ),
        (
          name: 'Write my own email',
          path: '/craft/own',
          prepare: (draft) => draft.setIntent(MessageIntent.own),
          after: null,
          content: () => find.widgetWithText(TextField, 'Subject'),
        ),
        (
          name: 'Campaigns',
          path: '/campaigns',
          prepare: null,
          after: null,
          content: () => cardWith("Save Stephen's Green"),
        ),
        (
          name: 'A campaign email',
          path: '/campaigns',
          prepare: null,
          after: (tester) async {
            await tester.tap(find.text("Save Stephen's Green"));
            await tester.pumpAndSettle();
          },
          content: () => find.byType(Card).first,
        ),
        (
          name: 'Choose a council',
          path: '/council',
          prepare: emailWritten,
          after: null,
          content: () => cardWith('Not sure? Find your area'),
        ),
        (
          name: 'Choose an area',
          path: '/council/fingal-county-council/lea',
          prepare: emailWritten,
          after: null,
          content: () => find.byType(Card).first,
        ),
        (
          name: 'Find your area',
          path: '/find-area',
          prepare: emailWritten,
          after: null,
          content: () => find.byType(TextField),
        ),
        (name: 'Review', path: '/review', prepare: areaChosen, after: null, content: () => find.byType(Card).first),
        (
          name: 'Connect your email',
          path: '/connect',
          prepare: areaChosen,
          after: null,
          content: () => find.byType(Card).first,
        ),
        (
          name: 'Privacy notice',
          path: '/privacy',
          prepare: null,
          after: null,
          content: () => find.text('Who is responsible'),
        ),
      ];

  for (final screen in screens) {
    Future<void> open(WidgetTester tester, double width) async {
      await openApp(tester, api, prepare: screen.prepare, path: screen.path);
      await screen.after?.call(tester);
      tester.view.physicalSize = Size(width, 2400);
      await tester.pumpAndSettle();
    }

    testWidgets('${screen.name}: on a wide screen the content stays in the reading column', (tester) async {
      await open(tester, 1600);

      final rect = tester.getRect(screen.content());
      final marginEachSide = (1600 - ContentWidth.form) / 2; // 440
      expect(rect.left, greaterThanOrEqualTo(marginEachSide - 0.5));
      expect(rect.right, lessThanOrEqualTo(1600 - marginEachSide + 0.5));
      expect(rect.width, greaterThan(100)); // the column is used, not collapsed
    });

    testWidgets('${screen.name}: on a phone the content fits the screen', (tester) async {
      await open(tester, 390);

      final rect = tester.getRect(screen.content());
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(390));
      expect(tester.takeException(), isNull);
    });

    // The privacy notice does not link to itself.
    final isPrivacyNotice = screen.path == '/privacy';
    Finder footerLink() => find.descendant(of: find.byType(AppFooter), matching: find.text('Privacy notice'));

    testWidgets('${screen.name}: ends with the footer', (tester) async {
      await open(tester, 390);

      expect(find.byType(AppFooter), findsOneWidget);
      expect(find.text(AppFooter.independence), findsOneWidget);
      expect(footerLink(), isPrivacyNotice ? findsNothing : findsOneWidget);
    });

    if (!isPrivacyNotice) {
      testWidgets('${screen.name}: the footer opens the privacy notice', (tester) async {
        await open(tester, 390);

        await tester.ensureVisible(footerLink());
        await tester.tap(footerLink());
        await tester.pumpAndSettle();

        expect(find.byType(PrivacyScreen), findsOneWidget);
      });
    }
  }
}
