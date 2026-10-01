import 'package:app/models/oauth_result.dart';
import 'package:app/providers/message_flow/message_flow_state.dart';
import 'package:flutter_test/flutter_test.dart';

// Riverpod 3 skips notifying listeners when a new state == the old one,
// so the field-less stages (Idle, Creating, Confirming, Sending) must
// never compare equal, or the progress display would stop updating.
// Equatable keeps them distinct by comparing types as well as props; this
// guards against that ever changing (e.g. a custom == override).
void main() {
  test('each field-less stage is distinct from the others', () {
    const stages = [MessageFlowIdle(), MessageFlowCreating(), MessageFlowConfirming(), MessageFlowSending()];

    for (final a in stages) {
      for (final b in stages) {
        expect(a == b, identical(a, b), reason: '${a.runtimeType} vs ${b.runtimeType}');
      }
    }
  });

  test('failures of different kinds are distinct even with the same message', () {
    expect(const LeaNotFoundFailure('x') == const RateLimitedFailure('x'), isFalse);
    expect(const RateLimitedFailure('x'), const RateLimitedFailure('x'));
  });

  test('a success and a failure never count as equal', () {
    const success = OAuthSuccess(token: 't', email: 'e', provider: 'p');
    const failure = OAuthFailure(errorCode: 't', errorDescription: 'e');

    expect(success == failure, isFalse);
  });
}
