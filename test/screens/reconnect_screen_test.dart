import 'package:app/models/message_intent.dart';
import 'package:app/providers/draft/draft_notifier.dart';
import 'package:app/widgets/app_footer.dart';
import 'package:app/widgets/content_width.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// Where a resident lands when their email connection has expired.
void main() {
  late FakeApi api;

  setUp(() => api = FakeApi());

  testWidgets('says the connection has expired and asks them to reconnect', (tester) async {
    await openApp(tester, api, path: '/reconnect');

    expect(find.text('Your email connection has expired. Please reconnect your email account.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Start again'), findsOneWidget);
  });

  testWidgets('has the footer at the foot of the window, below the message', (tester) async {
    await openApp(tester, api, path: '/reconnect');

    expect(find.byType(AppFooter), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(AppFooter)).dy,
      greaterThan(tester.getBottomLeft(find.widgetWithText(FilledButton, 'Start again')).dy),
    );
    expect(tester.getBottomLeft(find.byType(AppFooter)).dy, 2400); // openApp's window is 2400 high
  });

  testWidgets('Start again clears the draft and goes home', (tester) async {
    final container = await openApp(
      tester,
      api,
      prepare: (draft) => draft
        ..setIntent(MessageIntent.own)
        ..setSubject('Subject')
        ..setBody('Body'),
      path: '/reconnect',
    );

    await tester.tap(find.text('Start again'));
    await tester.pumpAndSettle();

    expect(find.text('What would you like to do?'), findsOneWidget);
    expect(container.read(draftNotifierProvider).subject, isEmpty);
  });

  testWidgets('on a wide screen the message stays in the reading column', (tester) async {
    await openApp(tester, api, path: '/reconnect');
    tester.view.physicalSize = const Size(1600, 1200);
    await tester.pumpAndSettle();

    final button = tester.getRect(find.widgetWithText(FilledButton, 'Start again'));
    expect(button.width, lessThanOrEqualTo(ContentWidth.form));
  });

  testWidgets('on a phone nothing overflows', (tester) async {
    await openApp(tester, api, path: '/reconnect');
    tester.view.physicalSize = const Size(360, 800);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
