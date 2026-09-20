import 'package:equatable/equatable.dart';

enum AuthStatus {
  /// Nothing known yet — no session, and no restore attempt made.
  unknown,

  /// A stored session is being restored at boot.
  checking,
  authenticated,

  /// A 401 was received, or a restore found nothing usable — the router
  /// sends the user to /reconnect from anywhere on this status.
  expired,
}

class AuthState extends Equatable {
  const AuthState._({required this.status, this.token, this.email, this.provider});

  const AuthState.unknown() : this._(status: AuthStatus.unknown);
  const AuthState.checking() : this._(status: AuthStatus.checking);
  const AuthState.expired() : this._(status: AuthStatus.expired);

  const AuthState.authenticated({required String token, required String email, required String provider})
    : this._(status: AuthStatus.authenticated, token: token, email: email, provider: provider);

  final AuthStatus status;
  final String? token;
  final String? email;
  final String? provider;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  @override
  List<Object?> get props => [status, token, email, provider];
}
