import 'package:equatable/equatable.dart';

/// What GET /email/callback/{provider} delivered in the URL fragment
/// (never the query string — see app/routers/email.py's docstring).
sealed class OAuthResult extends Equatable {
  const OAuthResult({this.clientState});

  /// The value this app made up before starting the connection, as the
  /// backend echoed it back (null if the fragment didn't carry one).
  /// OAuthClientStateStore.verify compares it with what was saved, so a
  /// link carrying someone else's token is never accepted.
  final String? clientState;
}

class OAuthSuccess extends OAuthResult {
  const OAuthSuccess({required this.token, required this.email, required this.provider, super.clientState});

  final String token;
  final String email;
  final String provider;

  @override
  List<Object?> get props => [token, email, provider, clientState];
}

class OAuthFailure extends OAuthResult {
  const OAuthFailure({required this.errorCode, required this.errorDescription, super.clientState});

  final String errorCode;
  final String errorDescription;

  @override
  List<Object?> get props => [errorCode, errorDescription, clientState];
}
