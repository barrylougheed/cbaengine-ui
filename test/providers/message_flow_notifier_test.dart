import 'dart:convert';

import 'package:app/api/api_client.dart';
import 'package:app/providers/message_flow/message_flow_notifier.dart';
import 'package:app/providers/message_flow/message_flow_state.dart';
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
    'topic': 'housing',
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
  late ApiClient apiClient;

  http.Response jsonResponse(Object body, int statusCode) {
    return http.Response(jsonEncode(body), statusCode, headers: {'content-type': 'application/json'});
  }

  setUp(() {
    httpClient = _MockHttpClient();
    apiClient = ApiClient(
      httpClient: httpClient,
      baseUrl: 'http://localhost:8000',
      getToken: () => 'the-token',
      onUnauthorized: () {},
    );
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
    final notifier = MessageFlowNotifier(apiClient);

    expect(notifier.state, const MessageFlowIdle());
  });

  test('drives create -> confirm -> send through to a result on success', () async {
    stubCreate(jsonResponse(_messageJson(id: 'msg-1', status: 'draft_created'), 201));
    stubPost('/messages/msg-1/confirm', jsonResponse(_messageJson(id: 'msg-1', status: 'awaiting_confirmation'), 200));
    stubPost('/messages/msg-1/send', jsonResponse(_messageJson(id: 'msg-1', status: 'sent'), 200));
    final notifier = MessageFlowNotifier(apiClient);

    await notifier.startFlow(localElectoralArea: 'fingal-balbriggan', topic: 'housing', subject: 'Subject', body: 'Body');

    final state = notifier.state;
    expect(state, isA<MessageFlowResult>());
    expect((state as MessageFlowResult).record.status.wireValue, 'sent');
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
    final notifier = MessageFlowNotifier(apiClient);

    await notifier.startFlow(localElectoralArea: 'fingal-balbriggan', topic: 'housing', subject: 'Subject', body: 'Body');

    final state = notifier.state as MessageFlowResult;
    expect(state.record.status.wireValue, 'failed');
    expect(state.record.detail, isNotNull);
  });

  test('a 404 on create maps to MessageFlowFailed(LeaNotFoundFailure)', () async {
    stubCreate(
      jsonResponse({
        'detail':
            "We couldn't verify the councillor for this Local Elective Area. Please check your Local Elective Area and try again.",
      }, 404),
    );
    final notifier = MessageFlowNotifier(apiClient);

    await notifier.startFlow(localElectoralArea: 'TEST-NOTFOUND', topic: 'housing', subject: 'Subject', body: 'Body');

    expect(notifier.state, isA<MessageFlowFailed>());
    expect((notifier.state as MessageFlowFailed).failure, isA<LeaNotFoundFailure>());
  });

  test('a 429 on send maps to MessageFlowFailed(RateLimitedFailure)', () async {
    stubCreate(jsonResponse(_messageJson(id: 'msg-1', status: 'draft_created'), 201));
    stubPost('/messages/msg-1/confirm', jsonResponse(_messageJson(id: 'msg-1', status: 'awaiting_confirmation'), 200));
    stubPost(
      '/messages/msg-1/send',
      jsonResponse({'detail': "You've already sent a message today. Please try again tomorrow."}, 429),
    );
    final notifier = MessageFlowNotifier(apiClient);

    await notifier.startFlow(localElectoralArea: 'fingal-balbriggan', topic: 'housing', subject: 'Subject', body: 'Body');

    expect((notifier.state as MessageFlowFailed).failure, isA<RateLimitedFailure>());
  });

  test('any other ApiException maps to MessageFlowFailed(GenericFlowFailure)', () async {
    stubCreate(jsonResponse({'detail': 'Could not complete the email connection with the provider.'}, 502));
    final notifier = MessageFlowNotifier(apiClient);

    await notifier.startFlow(localElectoralArea: 'fingal-balbriggan', topic: 'housing', subject: 'Subject', body: 'Body');

    expect((notifier.state as MessageFlowFailed).failure, isA<GenericFlowFailure>());
  });

  test('state transitions through creating/confirming/sending in order', () async {
    stubCreate(jsonResponse(_messageJson(id: 'msg-1', status: 'draft_created'), 201));
    stubPost('/messages/msg-1/confirm', jsonResponse(_messageJson(id: 'msg-1', status: 'awaiting_confirmation'), 200));
    stubPost('/messages/msg-1/send', jsonResponse(_messageJson(id: 'msg-1', status: 'sent'), 200));
    final notifier = MessageFlowNotifier(apiClient);
    final seen = <MessageFlowState>[];
    notifier.addListener((state) => seen.add(state), fireImmediately: false);

    await notifier.startFlow(localElectoralArea: 'fingal-balbriggan', topic: 'housing', subject: 'Subject', body: 'Body');

    expect(seen.map((s) => s.runtimeType).toList(), [
      MessageFlowCreating,
      MessageFlowConfirming,
      MessageFlowSending,
      MessageFlowResult,
    ]);
  });
}
