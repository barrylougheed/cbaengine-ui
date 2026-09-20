/// Build-time configuration — set via `--dart-define`, e.g.:
///   flutter run -d chrome --web-port 5173 \
///     --dart-define=API_BASE_URL=http://localhost:8000
///
/// Defaults to the CBA backend's own default local address so local dev
/// works with zero flags out of the box.
const String apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000');

/// The web app's own /connect route — GET /email/callback/{provider}
/// redirects here (not the root) with the OAuth result in the URL
/// fragment, so the reload naturally lands the router back on
/// ConnectEmailScreen, which reads Uri.base.fragment itself. Must be an
/// exact entry in the backend's CBA_ALLOWED_CLIENT_REDIRECT_URIS, and
/// its port must match whatever `--web-port` the dev server was started
/// with (see the README's local-dev notes).
const String oauthWebClientRedirectUri = String.fromEnvironment(
  'OAUTH_WEB_CLIENT_REDIRECT_URI',
  defaultValue: 'http://localhost:5173/connect',
);

/// The mobile app's custom URL scheme — must match the Android
/// intent-filter, the iOS CFBundleURLTypes entry, and the backend's
/// CBA_ALLOWED_CLIENT_REDIRECT_URIS, exactly. Provisional, like the
/// bundle ID it's derived from (com.cbaengine.app) — see the
/// implementation plan.
const String oauthMobileClientRedirectUri = 'cbaengine://oauth/callback';
