import 'package:app/config/app_config.dart';
import 'package:app/screens/privacy_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the privacy notice covers what residents must be told', (WidgetTester tester) async {
    // Tall enough that the (lazily built) ListView renders every section.
    tester.view.physicalSize = const Size(800, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: PrivacyScreen()));

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
