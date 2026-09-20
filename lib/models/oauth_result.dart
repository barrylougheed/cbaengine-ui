import 'package:equatable/equatable.dart';

/// What GET /email/callback/{provider} delivered in the URL fragment
/// (never the query string — see app/routers/email.py's docstring).
sealed class OAuthResult extends Equatable {
  const OAuthResult();
}

class OAuthSuccess extends OAuthResult {
  const OAuthSuccess({required this.token, required this.email, required this.provider});

  final String token;
  final String email;
  final String provider;

  @override
  List<Object?> get props => [token, email, provider];
}

class OAuthFailure extends OAuthResult {
  const OAuthFailure({required this.errorCode, required this.errorDescription});

  final String errorCode;
  final String errorDescription;

  @override
  List<Object?> get props => [errorCode, errorDescription];
}
