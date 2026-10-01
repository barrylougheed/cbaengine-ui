import 'package:app/providers/auth/auth_notifier.dart';
import 'package:app/providers/auth/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  AuthState state() => container.read(authNotifierProvider);
  AuthNotifier notifier() => container.read(authNotifierProvider.notifier);

  setUp(() => container = ProviderContainer.test());

  test('starts unknown', () {
    expect(state(), const AuthState.unknown());
    expect(state().isAuthenticated, isFalse);
  });

  test('setSession moves to authenticated with the given details', () {
    notifier().setSession(token: 'the-token', email: 'resident@example.com', provider: 'google');

    expect(state(), const AuthState.authenticated(token: 'the-token', email: 'resident@example.com', provider: 'google'));
    expect(state().isAuthenticated, isTrue);
  });

  test('markExpired moves to expired and drops the token', () {
    notifier().setSession(token: 'the-token', email: 'resident@example.com', provider: 'google');

    notifier().markExpired();

    expect(state(), const AuthState.expired());
    expect(state().token, isNull);
  });

  test('signOut resets to unknown', () {
    notifier().setSession(token: 'the-token', email: 'resident@example.com', provider: 'google');

    notifier().signOut();

    expect(state(), const AuthState.unknown());
  });
}
