import 'dart:convert';

import 'package:app/api/api_client.dart';
import 'package:app/providers/core_providers.dart';
import 'package:app/providers/message_flow/message_flow_notifier.dart';
import 'package:app/providers/message_flow/message_flow_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class _MockHttpClient extends Mock implements http.Client {}

class _FakeUri extends Fake implements Uri {}

Map<String, dynamic> _messageJson({required String id, required String status, String? detail}) {
  return {
    'id': id,
    'sender': 'resident@example.com',
    'local_electoral_area': 'fingal-balbriggan',
    'topics': ['custom'],
    'subject': 'Subject',
    'body': 'Body',
    'councillors': <Object>[],
    'cba_mail': 'monitor@cbaengine.example',
    'status': status,
    'detail': detail,
    'created_at': '2026-01-01T00:00:00Z',
    'updated_at': '2026-01-01T00:00:00Z',
    'sent_at': status == 'sent' ? '2026-01-01T00:00:00Z' : null,
    'status_history': <Object>[],
  };
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeUri());
  });

  late _MockHttpClient httpClient;
  late ProviderContainer container;
  MessageFlowState state() => container.read(messageFlowNotifierProvider);
  MessageFlowNotifier notifier() => container.read(messageFlowNotifierProvider.notifier);

  http.Response jsonResponse(Object body, int statusCode) {
    return http.Response(jsonEncode(body), statusCode, headers: {'content-type': 'application/json'});
  }

  setUp(() {
    httpClient = _MockHttpClient();
    final apiClient = ApiClient(
      httpClient: httpClient,
      baseUrl: 'http://localhost:8000',
      getToken: () => 'the-token',
      onUnauthorized: () {},
    );
    container = ProviderContainer.test(overrides: [apiClientProvider.overrideWithValue(apiClient)]);
  });

  void stubPost(String path, http.Response response) {
    when(
      () => httpClient.post(Uri.parse('http://localhost:8000$path'), headers: any(named: 'headers')),
    ).thenAnswer((_) async => response);
  }

  void stubCreate(http.Response response) {
    when(
      () => httpClient.post(
        Uri.parse('http://localhost:8000/messages'),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((_) async => response);
  }

  test('starts idle', () {
    expect(state(), const MessageFlowIdle());
  });

  test('drives create -> confirm -> send through to a result on success', () async {
    stubCreate(jsonResponse(_messageJson(id: 'msg-1', status: 'draft_created'), 201));
    stubPost('/messages/msg-1/confirm', jsonResponse(_messageJson(id: 'msg-1', status: 'awaiting_confirmation'), 200));
    stubPost('/messages/msg-1/send', jsonResponse(_messageJson(id: 'msg-1', status: 'sent'), 200));

    await notifier().startFlow(localElectoralArea: 'fingal-balbriggan', topics: ['custom'], subject: 'Subject', body: 'Body', senderName: 'Sam Resident');

    final result = state();
    expect(result, isA<MessageFlowResult>());
    expect((result as MessageFlowResult).record.status.wireValue, 'sent');
  });

  test('a backend-reported send failure is still a MessageFlowResult, not MessageFlowFailed', () async {
    stubCreate(jsonResponse(_messageJson(id: 'msg-1', status: 'draft_created'), 201));
    stubPost('/messages/msg-1/confirm', jsonResponse(_messageJson(id: 'msg-1', status: 'awaiting_confirmation'), 200));
    stubPost(
      '/messages/msg-1/send',
      jsonResponse(
        _messageJson(
          id: 'msg-1',
          status: 'failed',
          detail: 'The email could not be sent. No message was confirmed as sent. Please try again.',
        ),
        200,
      ),
    );

    await notifier().startFlow(localElectoralArea: 'fingal-balbriggan', topics: ['custom'], subject: 'Subject', body: 'Body', senderName: 'Sam Resident');

    final result = state() as MessageFlowResult;
    expect(result.record.status.wireValue, 'failed');
    expect(result.record.detail, isNotNull);
  });

  test('a 404 on create maps to MessageFlowFailed(LeaNotFoundFailure)', () async {
    stubCreate(
      jsonResponse({
        'detail':
            "We couldn't verify the councillor for this Local Elective Area. Please check your Local Elective Area and try again.",
      }, 404),
    );

    await notifier().startFlow(localElectoralArea: 'TEST-NOTFOUND', topics: ['custom'], subject: 'Subject', body: 'Body', senderName: 'Sam Resident');

    expect(state(), isA<MessageFlowFailed>());
    expect((state() as MessageFlowFailed).failure, isA<LeaNotFoundFailure>());
  });

  test('a 429 on send maps to MessageFlowFailed(RateLimitedFailure)', () async {
    stubCreate(jsonResponse(_messageJson(id: 'msg-1', status: 'draft_created'), 201));
    stubPost('/messages/msg-1/confirm', jsonResponse(_messageJson(id: 'msg-1', status: 'awaiting_confirmation'), 200));
    stubPost(
      '/messages/msg-1/send',
      jsonResponse({'detail': "You've already sent a message today. Please try again tomorrow."}, 429),
    );

    await notifier().startFlow(localElectoralArea: 'fingal-balbriggan', topics: ['custom'], subject: 'Subject', body: 'Body', senderName: 'Sam Resident');

    expect((state() as MessageFlowFailed).failure, isA<RateLimitedFailure>());
  });

  test('any other ApiException maps to MessageFlowFailed(GenericFlowFailure)', () async {
    stubCreate(jsonResponse({'detail': 'Could not complete the email connection with the provider.'}, 502));

    await notifier().startFlow(localElectoralArea: 'fingal-balbriggan', topics: ['custom'], subject: 'Subject', body: 'Body', senderName: 'Sam Resident');

    expect((state() as MessageFlowFailed).failure, isA<GenericFlowFailure>());
  });

  test('drafts the message with the topics, the variants shown and the sign-off name', () async {
    stubCreate(jsonResponse(_messageJson(id: 'msg-1', status: 'draft_created'), 201));
    stubPost('/messages/msg-1/confirm', jsonResponse(_messageJson(id: 'msg-1', status: 'awaiting_confirmation'), 200));
    stubPost('/messages/msg-1/send', jsonResponse(_messageJson(id: 'msg-1', status: 'sent'), 200));

    await notifier().startFlow(
      localElectoralArea: 'fingal-balbriggan',
      topics: ['housing-crisis', 'save-stephens-green'],
      subject: 'Subject',
      body: 'Body',
      senderName: 'Sam Resident',
      templateVariants: {'housing-crisis': 'v3', 'save-stephens-green': 'v1'},
    );

    final captured = verify(
      () => httpClient.post(
        Uri.parse('http://localhost:8000/messages'),
        headers: any(named: 'headers'),
        body: captureAny(named: 'body'),
      ),
    ).captured;
    final sent = jsonDecode(captured.single as String) as Map<String, dynamic>;
    expect(sent['topics'], ['housing-crisis', 'save-stephens-green']);
    expect(sent['template_variants'], {'housing-crisis': 'v3', 'save-stephens-green': 'v1'});
    expect(sent['sender_name'], 'Sam Resident');
  });

  test('state transitions through creating/confirming/sending in order', () async {
    stubCreate(jsonResponse(_messageJson(id: 'msg-1', status: 'draft_created'), 201));
    stubPost('/messages/msg-1/confirm', jsonResponse(_messageJson(id: 'msg-1', status: 'awaiting_confirmation'), 200));
    stubPost('/messages/msg-1/send', jsonResponse(_messageJson(id: 'msg-1', status: 'sent'), 200));
    final seen = <MessageFlowState>[];
    container.listen(messageFlowNotifierProvider, (previous, next) => seen.add(next));

    await notifier().startFlow(localElectoralArea: 'fingal-balbriggan', topics: ['custom'], subject: 'Subject', body: 'Body', senderName: 'Sam Resident');

    expect(seen.map((s) => s.runtimeType).toList(), [
      MessageFlowCreating,
      MessageFlowConfirming,
      MessageFlowSending,
      MessageFlowResult,
    ]);
  });
}
