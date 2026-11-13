import 'package:app/models/council.dart';
import 'package:app/models/councillor_preview.dart';
import 'package:app/models/lea.dart';
import 'package:app/models/message_intent.dart';
import 'package:app/providers/draft/draft_notifier.dart';
import 'package:app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// How the Review step looks: the email set out as a letter, then who it goes
/// to, then the consent notice. (What it says, and the button, are covered in
/// review_screen_test.dart.)
void main() {
  late FakeApi api;

  setUp(() => api = FakeApi());

  void reviewing(DraftNotifier draft) {
    draft
      ..selectCouncil(const Council(id: 'fingal-county-council', name: 'Fingal County Council'))
      ..selectLea(
        const Lea(
          id: 'swords',
          name: 'Swords',
          council: 'Fingal County Council',
          councillors: [
            CouncillorPreview(name: 'Aoife Byrne', party: 'Fine Gael'),
            CouncillorPreview(name: 'Conor Doyle', party: 'Independent'),
          ],
        ),
      )
      ..setIntent(MessageIntent.own)
      ..setSenderName('Sam Resident')
      ..setSubject('Housing in Swords')
      ..setBody('Please tell me what you are doing about housing.');
  }

  testWidgets('sets the email out as a letter: subject as its heading, then the text and the sign-off', (tester) async {
    await openApp(tester, api, prepare: reviewing, path: '/review');

    final letter = find.byKey(const Key('review-letter'));
    expect(letter, findsOneWidget);
    for (final line in ['Housing in Swords', 'Please tell me what you are doing about housing.', 'Sam Resident']) {
      expect(find.descendant(of: letter, matching: find.text(line)), findsOneWidget);
    }
    // The subject is the heading, so it is set larger than the text under it.
    final heading = tester.widget<Text>(find.text('Housing in Swords')).style?.fontSize ?? 0;
    final text = tester.widget<Text>(find.text('Please tell me what you are doing about housing.')).style?.fontSize;
    expect(heading, greaterThan(text ?? 16));
  });

  testWidgets('says how many councillors it goes to, and lists them with their party', (tester) async {
    await openApp(tester, api, prepare: reviewing, path: '/review');

    expect(find.text('This will be sent to 2 councillors'), findsOneWidget);
    expect(find.text('Aoife Byrne'), findsOneWidget);
    expect(find.text('Fine Gael'), findsOneWidget);
    expect(find.text('Conor Doyle'), findsOneWidget);
    expect(find.text('Independent'), findsOneWidget);
  });

  testWidgets("shows each councillor's initial in an olive tint", (tester) async {
    await openApp(tester, api, prepare: reviewing, path: '/review');

    for (final (index, initial) in ['A', 'C'].indexed) {
      final disc = tester.widget<DecoratedBox>(find.byKey(Key('councillor-initial-$index')));
      expect((disc.decoration as BoxDecoration).color, AppColors.softOlive);
      final letter = find.descendant(of: find.byKey(Key('councillor-initial-$index')), matching: find.text(initial));
      expect(tester.widget<Text>(letter).style?.color, AppColors.deepOlive);
    }
  });

  testWidgets('puts the consent notice in a tinted panel', (tester) async {
    await openApp(tester, api, prepare: reviewing, path: '/review');

    final panel = find.byKey(const Key('review-consent'));
    expect(panel, findsOneWidget);
    expect((tester.widget<DecoratedBox>(panel).decoration as BoxDecoration).color, AppColors.mist);
    expect(
      find.descendant(of: panel, matching: find.textContaining('By pressing "Connect email and send", you agree')),
      findsOneWidget,
    );
  });
}
