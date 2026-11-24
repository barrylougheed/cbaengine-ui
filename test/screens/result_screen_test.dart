import 'dart:async';
import 'dart:convert';

import 'package:app/api/api_client.dart';
import 'package:app/app.dart';
import 'package:app/models/message_intent.dart';
import 'package:app/providers/core_providers.dart';
import 'package:app/providers/message_flow/message_flow_notifier.dart';
import 'package:app/router.dart';
import 'package:app/theme/app_theme.dart';
import 'package:app/widgets/app_footer.dart';
import 'package:app/widgets/content_width.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The end of the flow: for a sent message, who it went to and where the copy
/// and any replies will be; for a failed one, the API's own explanation.
void main() {
  const councillors = [
    {'name': 'Ann One', 'email': 'ann.one@council.ie', 'party': 'Fine Gael'},
    {'name': 'Bob Two', 'email': 'bob.two@council.ie', 'party': 'Labour Party'},
  ];

  Map<String, dynamic> messageJson({
    required String status,
    List<Map<String, String>> recipients = councillors,
    String? detail,
  }) => {
    'id': 'msg-1',
    'sender': 'resident@example.com',
    'local_electoral_area': 'fingal-swords',
    'topics': ['custom'],
    'subject': 'Subject',
    'body': 'Body',
    'councillors': recipients,
    'cba_mail': 'monitor@cbaengine.example',
    'status': status,
    'detail': detail,
    'created_at': '2026-11-03T10:00:00Z',
    'updated_at': '2026-11-03T10:00:00Z',
    'sent_at': status == 'sent' ? '2026-11-03T10:00:00Z' : null,
    'status_history': <Object>[],
  };

  /// Runs the real flow against canned responses and opens the result.
  Future<void> openResult(WidgetTester tester, Map<String, dynamic> sentRecord) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    http.Response json(Object body, int status) =>
        http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});
    final client = MockClient((request) async {
      switch (request.url.path) {
        case '/messages':
          return json(messageJson(status: 'draft_created', recipients: const []), 201);
        case '/messages/msg-1/confirm':
          return json(messageJson(status: 'awaiting_confirmation', recipients: const []), 200);
        case '/messages/msg-1/send':
          return json(sentRecord, 200);
        default:
          return json({'councils': <Object>[]}, 200);
      }
    });

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer.test(
      retry: noAutomaticRetry,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        apiClientProvider.overrideWithValue(
          ApiClient(
            httpClient: client,
            baseUrl: 'http://localhost:8000',
            getToken: () => 'token',
            onUnauthorized: () {},
          ),
        ),
      ],
    );
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const CbaEngineApp()));
    await tester.pumpAndSettle();
    await container
        .read(messageFlowNotifierProvider.notifier)
        .startFlow(
          localElectoralArea: 'fingal-swords',
          intent: MessageIntent.own,
          topics: ['custom'],
          subject: 'Subject',
          body: 'Body',
          senderName: 'Sam Resident',
        );
    unawaited(container.read(routerProvider).push('/result'));
    await tester.pumpAndSettle();
  }

  testWidgets('a sent message says who it went to', (tester) async {
    await openResult(tester, messageJson(status: 'sent'));

    expect(find.text('Your message was sent.'), findsOneWidget);
    expect(find.text('Sent to 2 councillors'), findsOneWidget);
    expect(find.text('Ann One'), findsOneWidget);
    expect(find.text('Fine Gael'), findsOneWidget);
    expect(find.text('Bob Two'), findsOneWidget);
    expect(find.text('Labour Party'), findsOneWidget);
  });

  testWidgets('a sent message ends with the footer, below who it went to', (tester) async {
    await openResult(tester, messageJson(status: 'sent'));

    expect(find.byType(AppFooter), findsOneWidget);
    expect(tester.getTopLeft(find.byType(AppFooter)).dy, greaterThan(tester.getBottomLeft(find.text('Bob Two')).dy));
  });

  testWidgets('a failed message ends with the footer too', (tester) async {
    await openResult(tester, messageJson(status: 'failed', detail: 'It did not go.'));

    expect(find.text('It did not go.'), findsOneWidget);
    expect(find.byType(AppFooter), findsOneWidget);
  });

  testWidgets('it never shows a councillor email address', (tester) async {
    await openResult(tester, messageJson(status: 'sent'));

    expect(find.textContaining('council.ie'), findsNothing);
  });

  testWidgets('a single councillor is "1 councillor"', (tester) async {
    await openResult(tester, messageJson(status: 'sent', recipients: [councillors.first]));

    expect(find.text('Sent to 1 councillor'), findsOneWidget);
  });

  testWidgets('it says a copy went to the resident and that replies come to that inbox', (tester) async {
    await openResult(tester, messageJson(status: 'sent'));

    expect(
      find.text('A copy has been sent to resident@example.com, and any replies will come to that inbox.'),
      findsOneWidget,
    );
  });

  testWidgets('it does not offer to share the app', (tester) async {
    await openResult(tester, messageJson(status: 'sent'));

    expect(find.textContaining('hare'), findsNothing);
  });

  testWidgets('with no recipients on the record there is no list, just the outcome', (tester) async {
    await openResult(tester, messageJson(status: 'sent', recipients: const []));

    expect(find.text('Your message was sent.'), findsOneWidget);
    expect(find.textContaining('Sent to'), findsNothing);
  });

  testWidgets('a failed send shows the API explanation and no list of recipients', (tester) async {
    await openResult(
      tester,
      messageJson(
        status: 'failed',
        detail:
            'Delivered to: ann.one@council.ie. Failed to deliver to: bob.two@council.ie. '
            'Do not resend to the recipients already delivered to.',
      ),
    );

    expect(find.text('Your message could not be sent.'), findsOneWidget);
    expect(find.textContaining('Failed to deliver to'), findsOneWidget);
    expect(find.textContaining('Sent to'), findsNothing);
    expect(find.text('Ann One'), findsNothing);
  });

  testWidgets('Back to start is still there', (tester) async {
    await openResult(tester, messageJson(status: 'sent'));

    expect(find.text('Back to start'), findsOneWidget);
  });

  testWidgets('a sent message is marked with a green-olive tick, in the app success colour', (tester) async {
    await openResult(tester, messageJson(status: 'sent'));

    final tick = tester.widget<Icon>(find.byIcon(Icons.check_circle_outline));
    expect(tick.color, AppColors.success);
    // ...and each councillor it reached has a tick beside their name.
    final ticks = tester.widgetList<Icon>(find.byIcon(Icons.check_circle));
    expect(ticks, hasLength(2));
    expect(ticks.every((icon) => icon.color == AppColors.success), isTrue);
  });

  testWidgets('a failed message is marked with a red cross', (tester) async {
    await openResult(tester, messageJson(status: 'failed', detail: 'It did not go.'));

    final cross = tester.widget<Icon>(find.byIcon(Icons.error_outline));
    expect(cross.color, AppColors.error);
  });

  testWidgets('on a wide screen the outcome stays in the reading column', (tester) async {
    await openResult(tester, messageJson(status: 'sent'));
    tester.view.physicalSize = const Size(1600, 1600);
    await tester.pumpAndSettle();

    final list = tester.getRect(find.byType(Card).first);
    expect(list.left, greaterThanOrEqualTo((1600 - ContentWidth.form) / 2 - 0.5));
    expect(list.right, lessThanOrEqualTo(1600 - (1600 - ContentWidth.form) / 2 + 0.5));
  });

  testWidgets('on a phone nothing overflows', (tester) async {
    await openResult(tester, messageJson(status: 'sent'));
    tester.view.physicalSize = const Size(390, 1600);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
