import 'package:app/models/oauth_result.dart';
import 'package:app/services/oauth_fragment_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('success', () {
    test('parses token/email/provider, URL-decoded', () {
      final result = OauthFragmentParser.parse('token=abc123&email=resident%40example.com&provider=google');

      expect(result, const OAuthSuccess(token: 'abc123', email: 'resident@example.com', provider: 'google'));
    });

    test('carries the echoed client_state through', () {
      final result = OauthFragmentParser.parse(
        'token=abc123&email=resident%40example.com&provider=google&client_state=xyz-789',
      );

      expect(result?.clientState, 'xyz-789');
    });
  });

  group('failure', () {
    test('parses error/error_description, URL-decoded', () {
      final result = OauthFragmentParser.parse(
        'error=access_denied&error_description=Email+connection+was+not+completed.',
      );

      expect(
        result,
        const OAuthFailure(
          errorCode: 'access_denied',
          errorDescription: 'Email connection was not completed.',
        ),
      );
    });

    test('defaults error_description to empty when absent, rather than crashing', () {
      final result = OauthFragmentParser.parse('error=provider_unavailable');

      expect(result, const OAuthFailure(errorCode: 'provider_unavailable', errorDescription: ''));
    });

    test('carries the echoed client_state through on a failure too', () {
      final result = OauthFragmentParser.parse('error=access_denied&client_state=xyz-789');

      expect(result?.clientState, 'xyz-789');
    });

    test('error takes precedence even if token-shaped params are also present', () {
      final result = OauthFragmentParser.parse('error=access_denied&token=should-be-ignored');

      expect(result, isA<OAuthFailure>());
    });
  });

  group('not an OAuth return at all', () {
    test('an empty fragment returns null', () {
      expect(OauthFragmentParser.parse(''), isNull);
    });

    test('unrelated fragment content returns null', () {
      expect(OauthFragmentParser.parse('some_other_thing=1'), isNull);
    });

    test('a malformed success (missing a required field) returns null, not a crash', () {
      expect(OauthFragmentParser.parse('token=abc123&provider=google'), isNull);
    });
  });
}
