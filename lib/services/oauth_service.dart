import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../config/app_config.dart';
import '../models/oauth_result.dart';
import 'oauth_client_state_store.dart';
import 'oauth_fragment_parser.dart';

/// Ties the API client, url_launcher, and app_links together into one
/// platform-conditional connect() call. Not unit-tested — it's glue over
/// two plugins and a real browser navigation, which the implementation
/// plan calls out as manual/per-platform territory; OauthFragmentParser
/// (the actual parsing logic this delegates to) is the piece that's
/// TDD'd.
class OAuthService {
  OAuthService(this._apiClient, this._clientStateStore, {AppLinks? appLinks}) : _appLinks = appLinks ?? AppLinks();

  final ApiClient _apiClient;
  final OAuthClientStateStore _clientStateStore;
  final AppLinks _appLinks;

  /// Web: navigates the current tab away to the provider's consent
  /// screen and never returns — the page reloads on GET /email/callback's
  /// redirect back to oauthWebClientRedirectUri, and ConnectEmailScreen
  /// picks the result out of Uri.base.fragment itself on that fresh load.
  ///
  /// Mobile: opens the system browser/Custom Tabs and resolves once
  /// app_links delivers the cbaengine://oauth/callback redirect back
  /// into this same running app instance.
  Future<OAuthResult> connect({required String provider}) async {
    final clientRedirectUri = kIsWeb ? oauthWebClientRedirectUri : oauthMobileClientRedirectUri;
    final authorizationUrl = await _apiClient.authorizeEmail(
      provider: provider,
      clientRedirectUri: clientRedirectUri,
      // Checked on return by OAuthClientStateStore.verify.
      clientState: await _clientStateStore.create(),
    );
    final uri = Uri.parse(authorizationUrl);

    if (kIsWeb) {
      await launchUrl(uri, webOnlyWindowName: '_self');
      // Never actually observed — the tab navigates away before this
      // future would resolve.
      return Completer<OAuthResult>().future;
    }

    final resultFuture = _appLinks.uriLinkStream
        .map((redirected) => OauthFragmentParser.parse(redirected.fragment))
        .firstWhere((result) => result != null)
        .then((result) => result!);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw StateError('Could not open the sign-in page.');
    }
    return resultFuture;
  }
}
