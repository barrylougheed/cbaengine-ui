import '../models/oauth_result.dart';

/// Parses the URL fragment GET /email/callback/{provider} redirects to
/// when `client_redirect_uri` was used — never the query string (see
/// app/routers/email.py's docstring on why the backend uses a fragment).
class OauthFragmentParser {
  const OauthFragmentParser._();

  /// Returns null when `fragment` isn't an OAuth return at all (a plain
  /// page load, or an app link opened without one) — distinct from
  /// OAuthFailure, which means the flow itself completed but failed.
  static OAuthResult? parse(String fragment) {
    if (fragment.isEmpty) return null;
    final params = Uri.splitQueryString(fragment);
    final clientState = params['client_state'];

    final error = params['error'];
    if (error != null) {
      return OAuthFailure(
        errorCode: error,
        errorDescription: params['error_description'] ?? '',
        clientState: clientState,
      );
    }

    final token = params['token'];
    final email = params['email'];
    final provider = params['provider'];
    if (token != null && email != null && provider != null) {
      return OAuthSuccess(token: token, email: email, provider: provider, clientState: clientState);
    }

    return null;
  }
}
