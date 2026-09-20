import 'package:app/providers/auth/auth_notifier.dart';
import 'package:app/providers/auth/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts unknown', () {
    final notifier = AuthNotifier();

    expect(notifier.state, const AuthState.unknown());
    expect(notifier.state.isAuthenticated, isFalse);
  });

  test('setSession moves to authenticated with the given details', () {
    final notifier = AuthNotifier();

    notifier.setSession(token: 'the-token', email: 'resident@example.com', provider: 'google');

    expect(
      notifier.state,
      const AuthState.authenticated(token: 'the-token', email: 'resident@example.com', provider: 'google'),
    );
    expect(notifier.state.isAuthenticated, isTrue);
  });

  test('markExpired moves to expired and drops the token', () {
    final notifier = AuthNotifier();
    notifier.setSession(token: 'the-token', email: 'resident@example.com', provider: 'google');

    notifier.markExpired();

    expect(notifier.state, const AuthState.expired());
    expect(notifier.state.token, isNull);
  });

  test('signOut resets to unknown', () {
    final notifier = AuthNotifier();
    notifier.setSession(token: 'the-token', email: 'resident@example.com', provider: 'google');

    notifier.signOut();

    expect(notifier.state, const AuthState.unknown());
  });
}
