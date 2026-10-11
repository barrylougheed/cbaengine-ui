import 'dart:convert';

import 'package:app/api/api_client.dart';
import 'package:app/api/api_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class _MockHttpClient extends Mock implements http.Client {}

class _FakeUri extends Fake implements Uri {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeUri());
  });

  late _MockHttpClient httpClient;
  late String? token;
  late bool unauthorizedCalled;
  late ApiClient client;

  setUp(() {
    httpClient = _MockHttpClient();
    token = null;
    unauthorizedCalled = false;
    client = ApiClient(
      httpClient: httpClient,
      baseUrl: 'http://localhost:8000',
      getToken: () => token,
      onUnauthorized: () => unauthorizedCalled = true,
    );
  });

  http.Response jsonResponse(Object body, int statusCode) {
    return http.Response(jsonEncode(body), statusCode, headers: {'content-type': 'application/json'});
  }

  const messageJson = {
    'id': 'msg-1',
    'sender': 'resident@example.com',
    'local_electoral_area': 'fingal-balbriggan',
    'topics': ['housing-crisis'],
    'subject': 'Subject',
    'body': 'Body',
    'councillors': [
      {'name': 'A Councillor', 'email': 'a@example.com', 'party': 'Independent'},
    ],
    'cba_mail': 'monitor@cbaengine.example',
    'status': 'draft_created',
    'detail': null,
    'created_at': '2026-01-01T00:00:00Z',
    'updated_at': '2026-01-01T00:00:00Z',
    'sent_at': null,
    'status_history': [
      {'status': 'draft_created', 'at': '2026-01-01T00:00:00Z'},
    ],
  };

  group('getMessage', () {
    test('requires auth: throws UnauthenticatedException without a token', () async {
      expect(() => client.getMessage('msg-1'), throwsA(isA<UnauthenticatedException>()));
      verifyZeroInteractions(httpClient);
    });

    test('returns the MessageRecord on 200 with the bearer token attached', () async {
      token = 'the-token';
      when(
        () => httpClient.get(
          Uri.parse('http://localhost:8000/messages/msg-1'),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer((_) async => jsonResponse(messageJson, 200));

      final record = await client.getMessage('msg-1');

      expect(record.id, 'msg-1');
      final captured = verify(
        () => httpClient.get(
          Uri.parse('http://localhost:8000/messages/msg-1'),
          headers: captureAny(named: 'headers'),
        ),
      ).captured;
      expect((captured.single as Map)['Authorization'], 'Bearer the-token');
    });

    test('throws NotFoundException on 404 (not found or not owned)', () async {
      token = 'the-token';
      when(
        () => httpClient.get(
          Uri.parse('http://localhost:8000/messages/msg-1'),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer((_) async => jsonResponse({'detail': 'Message not found.'}, 404));

      expect(() => client.getMessage('msg-1'), throwsA(isA<NotFoundException>()));
    });
  });

  group('getTopics', () {
    test('returns the topics with their titles, and the email layout, on 200', () async {
      when(() => httpClient.get(Uri.parse('http://localhost:8000/topics'))).thenAnswer(
        (_) async => jsonResponse({
          'topics': [
            {'id': 'housing-crisis', 'title': 'Housing Crisis'},
            {'id': 'save-stephens-green', 'title': "Save Stephen's Green"},
          ],
          'email_layout': {'greeting_format': 'Dear Councillor {name},', 'sign_off': 'Kind regards,'},
        }, 200),
      );

      final catalogue = await client.getTopics();

      expect(catalogue.topics.map((t) => t.id), ['housing-crisis', 'save-stephens-green']);
      expect(catalogue.topics.map((t) => t.title), ['Housing Crisis', "Save Stephen's Green"]);
      expect(catalogue.emailLayout.greetingFor('Conor Dowling'), 'Dear Councillor Conor Dowling,');
      expect(catalogue.emailLayout.signOff, 'Kind regards,');
    });
  });

  group('composeTopics', () {
    const composedJson = {
      'topics': ['housing-crisis', 'save-stephens-green'],
      'variants': {'housing-crisis': 'v3', 'save-stephens-green': 'v1'},
      'subject': "Your stance on Housing Crisis and Save Stephen's Green",
      'body': 'Housing Crisis\nSome text.',
      'footer': 'Started from a CBA topic template.',
    };

    void stubCompose(http.Response response) {
      when(
        () => httpClient.post(
          Uri.parse('http://localhost:8000/topics/compose'),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => response);
    }

    test('needs no sign-in: posts the area, topics and pinned variants with no Authorization header', () async {
      stubCompose(jsonResponse(composedJson, 200));

      final composed = await client.composeTopics(
        localElectoralArea: 'fingal-balbriggan',
        topics: ['housing-crisis', 'save-stephens-green'],
        variants: {'housing-crisis': 'v3'},
      );

      expect(composed.topics, ['housing-crisis', 'save-stephens-green']);
      expect(composed.variants, {'housing-crisis': 'v3', 'save-stephens-green': 'v1'});
      expect(composed.subject, startsWith('Your stance on'));
      expect(composed.footer, 'Started from a CBA topic template.');
      final captured = verify(
        () => httpClient.post(
          Uri.parse('http://localhost:8000/topics/compose'),
          headers: captureAny(named: 'headers'),
          body: captureAny(named: 'body'),
        ),
      ).captured;
      expect((captured[0] as Map).containsKey('Authorization'), isFalse);
      expect(jsonDecode(captured[1] as String), {
        'local_electoral_area': 'fingal-balbriggan',
        'topics': ['housing-crisis', 'save-stephens-green'],
        'variants': {'housing-crisis': 'v3'},
      });
    });

    test('throws NotFoundException on 404 (unknown area or topic)', () async {
      stubCompose(jsonResponse({'detail': 'Topic not found.'}, 404));

      expect(
        () => client.composeTopics(localElectoralArea: 'fingal-balbriggan', topics: ['nope']),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('keeps the server\'s message when too many topics were chosen (422 with a plain detail)', () async {
      stubCompose(jsonResponse({'detail': 'Too many topics for one email. Please choose fewer.'}, 422));

      await expectLater(
        client.composeTopics(localElectoralArea: 'fingal-balbriggan', topics: ['a', 'b']),
        throwsA(
          isA<ApiException>().having((e) => e.message, 'message', 'Too many topics for one email. Please choose fewer.'),
        ),
      );
    });

    test('throws NetworkException when there is no response', () async {
      when(
        () => httpClient.post(any(), headers: any(named: 'headers'), body: any(named: 'body')),
      ).thenThrow(Exception('offline'));

      expect(
        () => client.composeTopics(localElectoralArea: 'fingal-balbriggan', topics: ['housing-crisis']),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  group('getCouncils', () {
    test('returns councils on 200', () async {
      when(() => httpClient.get(Uri.parse('http://localhost:8000/councils'))).thenAnswer(
        (_) async => jsonResponse({
          'councils': [
            {'id': 'fingal-county-council', 'name': 'Fingal County Council'},
          ],
        }, 200),
      );

      final councils = await client.getCouncils();

      expect(councils, hasLength(1));
      expect(councils.first.id, 'fingal-county-council');
      expect(councils.first.name, 'Fingal County Council');
    });
  });

  group('getLeasForCouncil', () {
    test('returns LEAs with councillor name/party previews on 200', () async {
      when(
        () => httpClient.get(Uri.parse('http://localhost:8000/councils/fingal-county-council/leas')),
      ).thenAnswer(
        (_) async => jsonResponse({
          'leas': [
            {
              'id': 'fingal-balbriggan',
              'name': 'Balbriggan',
              'council': 'Fingal County Council',
              'councillors': [
                {'name': 'A Councillor', 'party': 'Independent'},
              ],
            },
          ],
        }, 200),
      );

      final leas = await client.getLeasForCouncil('fingal-county-council');

      expect(leas, hasLength(1));
      expect(leas.first.councillors.single.name, 'A Councillor');
      expect(leas.first.councillors.single.party, 'Independent');
    });

    test('throws NotFoundException on 404', () async {
      when(
        () => httpClient.get(Uri.parse('http://localhost:8000/councils/not-real/leas')),
      ).thenAnswer((_) async => jsonResponse({'detail': 'Council not found.'}, 404));

      expect(
        () => client.getLeasForCouncil('not-real'),
        throwsA(isA<NotFoundException>().having((e) => e.message, 'message', 'Council not found.')),
      );
    });
  });

  group('getLeas', () {
    test('returns all public LEAs on 200', () async {
      when(() => httpClient.get(Uri.parse('http://localhost:8000/leas'))).thenAnswer(
        (_) async => jsonResponse({'leas': <Object>[]}, 200),
      );

      final leas = await client.getLeas();

      expect(leas, isEmpty);
    });
  });

  group('createMessage', () {
    test('requires auth: throws UnauthenticatedException without a token, no network call', () async {
      expect(
        () => client.createMessage(
          localElectoralArea: 'fingal-balbriggan',
          topics: ['custom'],
          subject: 'Subject',
          body: 'Body',
          senderName: 'Sam Resident',
        ),
        throwsA(isA<UnauthenticatedException>()),
      );
      verifyZeroInteractions(httpClient);
    });

    test('posts with the bearer token and decodes the MessageRecord on 201', () async {
      token = 'the-token';
      when(
        () => httpClient.post(
          Uri.parse('http://localhost:8000/messages'),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => jsonResponse(messageJson, 201));

      final record = await client.createMessage(
        localElectoralArea: 'fingal-balbriggan',
        topics: ['custom'],
        subject: 'Subject',
        body: 'Body',
        senderName: 'Sam Resident',
      );

      expect(record.id, 'msg-1');
      final captured = verify(
        () => httpClient.post(
          Uri.parse('http://localhost:8000/messages'),
          headers: captureAny(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).captured;
      expect((captured.single as Map)['Authorization'], 'Bearer the-token');
    });

    test('sends the topics, the variants shown and the name for the sign-off', () async {
      token = 'the-token';
      when(
        () => httpClient.post(
          Uri.parse('http://localhost:8000/messages'),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => jsonResponse(messageJson, 201));

      await client.createMessage(
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
      expect(jsonDecode(captured.single as String), {
        'local_electoral_area': 'fingal-balbriggan',
        'topics': ['housing-crisis', 'save-stephens-green'],
        'template_variants': {'housing-crisis': 'v3', 'save-stephens-green': 'v1'},
        'subject': 'Subject',
        'body': 'Body',
        'sender_name': 'Sam Resident',
      });
    });

    test('throws UnauthorizedException on 401 and calls onUnauthorized', () async {
      token = 'expired-token';
      when(
        () => httpClient.post(
          Uri.parse('http://localhost:8000/messages'),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => jsonResponse(
          {'detail': 'Your email connection has expired. Please reconnect your email account.'},
          401,
        ),
      );

      await expectLater(
        client.createMessage(
          localElectoralArea: 'fingal-balbriggan',
          topics: ['custom'],
          subject: 'Subject',
          body: 'Body',
          senderName: 'Sam Resident',
        ),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(unauthorizedCalled, isTrue);
    });

    test('throws NotFoundException on 404 (LEA not found)', () async {
      token = 'the-token';
      when(
        () => httpClient.post(
          Uri.parse('http://localhost:8000/messages'),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => jsonResponse({
          'detail':
              "We couldn't verify the councillor for this Local Elective Area. Please check your Local Elective Area and try again.",
        }, 404),
      );

      expect(
        () => client.createMessage(
          localElectoralArea: 'TEST-NOTFOUND',
          topics: ['custom'],
          subject: 'Subject',
          body: 'Body',
          senderName: 'Sam Resident',
        ),
        throwsA(isA<NotFoundException>()),
      );
    });

    test('throws ValidationException with parsed field errors on 422 (list detail)', () async {
      token = 'the-token';
      when(
        () => httpClient.post(
          Uri.parse('http://localhost:8000/messages'),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => jsonResponse({
          'detail': [
            {
              'type': 'value_error',
              'loc': ['body', 'topics'],
              'msg': 'Value error, unknown topic: not-a-topic',
              'input': ['not-a-topic'],
            },
          ],
        }, 422),
      );

      try {
        await client.createMessage(
          localElectoralArea: 'fingal-balbriggan',
          topics: ['not-a-topic'],
          subject: 'Subject',
          body: 'Body',
          senderName: 'Sam Resident',
        );
        fail('expected ValidationException');
      } on ValidationException catch (e) {
        expect(e.errors.single.loc, ['body', 'topics']);
        expect(e.errors.single.msg, 'Value error, unknown topic: not-a-topic');
      }
    });
  });

  group('confirmMessage', () {
    test('throws ConflictException on 409 (wrong state)', () async {
      token = 'the-token';
      when(
        () => httpClient.post(
          Uri.parse('http://localhost:8000/messages/msg-1/confirm'),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer(
        (_) async => jsonResponse({'detail': "Message cannot be confirmed from status 'sent'."}, 409),
      );

      expect(() => client.confirmMessage('msg-1'), throwsA(isA<ConflictException>()));
    });
  });

  group('sendMessage', () {
    test('throws RateLimitedException on 429', () async {
      token = 'the-token';
      when(
        () => httpClient.post(
          Uri.parse('http://localhost:8000/messages/msg-1/send'),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer(
        (_) async => jsonResponse({
          'detail': "You've already sent a message today. Please try again tomorrow.",
        }, 429),
      );

      expect(() => client.sendMessage('msg-1'), throwsA(isA<RateLimitedException>()));
    });

    test('a failed-send outcome is a normal 200 return, not an exception', () async {
      token = 'the-token';
      const failedJson = {
        'id': 'msg-1',
        'sender': 'resident@example.com',
        'local_electoral_area': 'fingal-balbriggan',
        'topics': ['housing-crisis'],
        'subject': 'Subject',
        'body': 'Body',
        'councillors': <Object>[],
        'cba_mail': 'monitor@cbaengine.example',
        'status': 'failed',
        'detail': 'The email could not be sent. No message was confirmed as sent. Please try again.',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
        'sent_at': null,
        'status_history': <Object>[],
      };
      when(
        () => httpClient.post(
          Uri.parse('http://localhost:8000/messages/msg-1/send'),
          headers: any(named: 'headers'),
        ),
      ).thenAnswer((_) async => jsonResponse(failedJson, 200));

      final record = await client.sendMessage('msg-1');

      expect(record.status.wireValue, 'failed');
      expect(record.detail, isNotNull);
    });
  });

  group('authorizeEmail', () {
    test('sends client_redirect_uri and client_state, and returns the authorization_url on 200', () async {
      when(
        () => httpClient.get(
          Uri.parse(
            'http://localhost:8000/email/authorize/google'
            '?client_redirect_uri=cbaengine%3A%2F%2Foauth%2Fcallback&client_state=abc-123',
          ),
        ),
      ).thenAnswer((_) async => jsonResponse({'authorization_url': 'https://accounts.google.com/...'}, 200));

      final url = await client.authorizeEmail(
        provider: 'google',
        clientRedirectUri: 'cbaengine://oauth/callback',
        clientState: 'abc-123',
      );

      expect(url, 'https://accounts.google.com/...');
    });

    test('throws ServiceUnavailableException on 503', () async {
      when(
        () => httpClient.get(
          Uri.parse(
            'http://localhost:8000/email/authorize/google'
            '?client_redirect_uri=cbaengine%3A%2F%2Foauth%2Fcallback&client_state=abc-123',
          ),
        ),
      ).thenAnswer((_) async => jsonResponse({'detail': 'CBA_GOOGLE_CLIENT_ID is not set.'}, 503));

      expect(
        () => client.authorizeEmail(
          provider: 'google',
          clientRedirectUri: 'cbaengine://oauth/callback',
          clientState: 'abc-123',
        ),
        throwsA(isA<ServiceUnavailableException>()),
      );
    });
  });

  group('network failure', () {
    test('a transport error becomes a NetworkException', () async {
      when(
        () => httpClient.get(Uri.parse('http://localhost:8000/topics')),
      ).thenThrow(http.ClientException('Connection refused'));

      expect(() => client.getTopics(), throwsA(isA<NetworkException>()));
    });
  });
}
