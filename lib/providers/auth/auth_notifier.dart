import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_state.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState.unknown());

  void checking() {
    state = const AuthState.checking();
  }

  void setSession({required String token, required String email, required String provider}) {
    state = AuthState.authenticated(token: token, email: email, provider: provider);
  }

  /// The single choke point the router watches for the global "any 401
  /// -> reconnect" rule, regardless of which screen triggered it.
  void markExpired() {
    state = const AuthState.expired();
  }

  void signOut() {
    state = const AuthState.unknown();
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier());
