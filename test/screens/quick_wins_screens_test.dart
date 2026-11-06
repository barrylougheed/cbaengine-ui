import 'dart:async';
import 'dart:convert';

import 'package:app/app.dart';
import 'package:app/models/message_intent.dart';
import 'package:app/providers/draft/draft_notifier.dart';
import 'package:app/providers/core_providers.dart';
import 'package:app/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What a resident is told at the start (home), when choosing an area (who
/// they will be writing to, and how many) and before connecting (what they are
/// agreeing to).
void main() {
  late ProviderContainer container;
  late bool councilsFail;

  http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json'},
  );

  Future<http.Response> handle(http.Request request) async {
    switch (request.url.path) {
      case '/councils':
        if (councilsFail) return jsonResponse({'detail': 'down'}, 500);
        return jsonResponse({
          'councils': [
            {
              'id': 'carlow-county-council',
              'name': 'Carlow County Council',
              'area_count': 3,
              'councillor_count': 18,
            },
            {
              'id': 'dublin-city-council',
              'name': 'Dublin City Council',
              'area_count': 11,
              'councillor_count': 63,
            },
          ],
        });
      case '/councils/fingal-county-council/leas':
        return jsonResponse({
          'leas': [
            {
              'id': 'fingal-balbriggan',
              'name': 'Balbriggan',
              'council': 'Fingal County Council',
              'councillors': [
                {'name': 'Ann One', 'party': 'Fine Gael'},
                {'name': 'Bob Two', 'party': 'Labour Party'},
                {'name': 'Cora Three', 'party': 'Independent'},
              ],
            },
            {
              'id': 'fingal-swords',
              'name': 'Swords',
              'council': 'Fingal County Council',
              'councillors': [
                {'name': 'Dan Four', 'party': 'Sinn Féin'},
                {'name': 'Eve Five', 'party': 'Fianna Fáil'},
              ],
            },
            {
              'id': 'fingal-ongar',
              'name': 'Ongar',
              'council': 'Fingal County Council',
              'councillors': [
                {'name': 'Finn Six', 'party': 'Green Party'},
              ],
            },
          ],
        });
      default:
        return jsonResponse({});
    }
  }

  Future<void> open(WidgetTester tester, {String? path}) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer.test(
      retry: noAutomaticRetry,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        httpClientProvider.overrideWithValue(MockClient(handle)),
      ],
    );
    // The council and area come after the email, so there has to be one.
    container.read(draftNotifierProvider.notifier)
      ..setIntent(MessageIntent.own)
      ..setSenderName('Sam Resident')
      ..setSubject('Subject')
      ..setBody('Body');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CbaEngineApp(),
      ),
    );
    await tester.pumpAndSettle();
    if (path != null) {
      unawaited(container.read(routerProvider).push(path));
      await tester.pumpAndSettle();
    }
  }

  setUp(() => councilsFail = false);

  group('home', () {
    testWidgets('explains how it works, in three steps', (tester) async {
      await open(tester);

      expect(find.text('How it works'), findsOneWidget);
      expect(find.text('Craft an email, or back a campaign.'), findsOneWidget);
      expect(
        find.text(
          'Choose your council and area, then review your message and who it goes to.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Connect your Gmail or Outlook account. Your message is sent straight away, from your own account, with a copy to you.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('says up front which accounts can send', (tester) async {
      await open(tester);

      expect(
        find.text("You'll need a Gmail, Outlook or Hotmail account to send."),
        findsOneWidget,
      );
    });

    testWidgets('says how many councillors and councils you can write to', (
      tester,
    ) async {
      await open(tester);

      expect(
        find.text('Write to any of 81 councillors across 2 councils.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'still works, without the total, if the councils cannot be loaded',
      (tester) async {
        councilsFail = true;
        await open(tester);

        expect(find.text('How it works'), findsOneWidget);
        expect(find.textContaining('Write to any of'), findsNothing);
      },
    );
  });

  group('area picker', () {
    testWidgets('says how many areas and councillors the council has', (
      tester,
    ) async {
      await open(tester, path: '/council/fingal-county-council/lea');

      expect(
        find.text('Fingal County Council · 3 areas · 6 councillors'),
        findsOneWidget,
      );
    });

    testWidgets('each area says how many councillors it has and who they are', (
      tester,
    ) async {
      await open(tester, path: '/council/fingal-county-council/lea');

      expect(find.text('3 councillors'), findsOneWidget);
      expect(find.text('Ann One, Bob Two, Cora Three'), findsOneWidget);
      expect(find.text('2 councillors'), findsOneWidget);
      expect(find.text('Dan Four, Eve Five'), findsOneWidget);
      expect(find.text('1 councillor'), findsOneWidget);
      expect(find.text('Finn Six'), findsOneWidget);
    });
  });

  group('connect email', () {
    testWidgets('says what you are agreeing to before you connect', (
      tester,
    ) async {
      await open(tester, path: '/connect');

      expect(
        find.text('Connect the email account you want to send from.'),
        findsOneWidget,
      );
      expect(
        find.text(
          "We ask for permission to send email from your account, and nothing else. We can't read your messages or see your contacts.",
        ),
        findsOneWidget,
      );
      expect(
        find.text('Your message is sent as soon as you connect.'),
        findsOneWidget,
      );
      expect(
        find.text('You get a copy, and any replies come to your inbox.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Works with Google (Gmail) and Microsoft (Outlook, Hotmail) accounts.',
        ),
        findsOneWidget,
      );
    });
  });
}
