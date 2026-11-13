import 'package:app/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  testWidgets('the privacy notice covers what residents must be told', (WidgetTester tester) async {
    // Opened through the app, as a resident reaches it (its header needs the router).
    await openApp(tester, FakeApi(), path: '/privacy');
    // Tall enough that the (lazily built) ListView renders every section.
    tester.view.physicalSize = const Size(900, 14000);
    await tester.pumpAndSettle();

    final text = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .join('\n');

    expect(text, contains(privacyContactEmail));
    expect(text, contains('monitoring mailbox'));
    expect(text, contains('400 days'));
    expect(text, contains('explicit consent'));
    // The usage report names senders, so the notice says what it holds and who sees it.
    expect(text, contains('how many messages each email address has sent'));
    expect(text, contains('the CBAEngine team sees this count'));
    // The place search sends what they type to the server: say what happens to it.
    expect(text, contains('Finding your area'));
    expect(text, contains('not stored'));
    // The consent is given by pressing Review's button, so it names it.
    expect(text, contains('Connect email and send'));
    expect(text, isNot(contains('"Continue"')));
    expect(text, contains('publish'));
    expect(text, contains('Data Protection Commission'));
    expect(text, contains('16 and over'));
  });
}
