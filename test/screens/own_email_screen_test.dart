import 'package:app/models/message_intent.dart';
import 'package:app/providers/draft/draft_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// Writing your own email: the resident's own subject and message, for views
/// the issue proposals do not cover. No footer, since nothing here started from
/// a template.
void main() {
  late FakeApi api;

  setUp(() => api = FakeApi());

  // The text fields, in the order they appear: name, subject, message.
  TextField field(WidgetTester tester, int index) => tester.widget<TextField>(find.byType(TextField).at(index));
  String text(WidgetTester tester, int index) => field(tester, index).controller!.text;
  bool continueEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue')).onPressed != null;

  Future<ProviderContainer> openOwn(WidgetTester tester) =>
      openApp(tester, api, prepare: (draft) => draft.setIntent(MessageIntent.own), path: '/craft/own');

  testWidgets('shows empty fields for the name, subject and message, and no footer', (tester) async {
    await openOwn(tester);

    expect(text(tester, 0), '');
    expect(text(tester, 1), '');
    expect(text(tester, 2), '');
    expect(find.textContaining('Started from a topic template.'), findsNothing);
    expect(continueEnabled(tester), isFalse);
  });

  testWidgets('explains what it is for', (tester) async {
    await openOwn(tester);

    expect(
      find.text('Say what you think in your own words, including views the issue proposals do not cover.'),
      findsOneWidget,
    );
  });

  testWidgets('explains what is added around the message', (tester) async {
    await openOwn(tester);

    expect(find.textContaining('Dear Councillor <name>,'), findsOneWidget);
    expect(find.textContaining('Kind regards,'), findsOneWidget);
  });

  testWidgets('can continue once there is a name, a subject and a message', (tester) async {
    await openOwn(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Sam Resident');
    await tester.enterText(find.byType(TextField).at(1), 'Bins on Main Street');
    await tester.pumpAndSettle();
    expect(continueEnabled(tester), isFalse);

    await tester.enterText(find.byType(TextField).at(2), 'The bins have not been collected.');
    await tester.pumpAndSettle();

    expect(continueEnabled(tester), isTrue);
  });

  testWidgets('text left in double square brackets is flagged and blocks continuing', (tester) async {
    await openOwn(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Sam Resident');
    await tester.enterText(find.byType(TextField).at(1), 'Subject');
    await tester.enterText(find.byType(TextField).at(2), 'Body');
    await tester.pumpAndSettle();
    expect(continueEnabled(tester), isTrue);

    await tester.enterText(find.byType(TextField).at(2), 'Body [[context: fill me in]]');
    await tester.pumpAndSettle();

    expect(find.textContaining('double square brackets'), findsOneWidget);
    expect(continueEnabled(tester), isFalse);
  });

  testWidgets('Continue opens the council step', (tester) async {
    await openOwn(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Sam Resident');
    await tester.enterText(find.byType(TextField).at(1), 'Subject');
    await tester.enterText(find.byType(TextField).at(2), 'Body');
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Select your council'), findsOneWidget);
  });

  testWidgets('says this is step 1 of 5', (tester) async {
    await openOwn(tester);

    expect(find.textContaining('Step 1 of 5'), findsOneWidget);
  });

  testWidgets('what was typed is still there after going on and coming back', (tester) async {
    final container = await openOwn(tester);
    await tester.enterText(find.byType(TextField).at(0), 'Sam Resident');
    await tester.enterText(find.byType(TextField).at(1), 'Subject');
    await tester.enterText(find.byType(TextField).at(2), 'Body');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    tester.state<NavigatorState>(find.byType(Navigator).last).pop();
    await tester.pumpAndSettle();

    expect(text(tester, 1), 'Subject');
    expect(container.read(draftNotifierProvider).body, 'Body');
  });
}
