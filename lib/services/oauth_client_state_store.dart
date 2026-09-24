import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/oauth_result.dart';

/// Makes sure a returned email connection is one *this* app started.
///
/// Before leaving for Google/Microsoft, the app makes up a random value
/// (create()), keeps it, and sends it to GET /email/authorize as
/// `client_state`; the backend echoes it back alongside the token.
/// verify() only accepts a successful connection that carries that exact
/// value. Without it, anyone could connect their own email and send a
/// resident a link like `.../connect#token=<their token>` — the app would
/// treat itself as connected to the attacker's account, and the
/// resident's message would go out from it.
///
/// Kept in SharedPreferences rather than memory because on web the whole
/// app reloads when the provider redirects back.
class OAuthClientStateStore {
  OAuthClientStateStore(this._prefs, {Random? random}) : _random = random ?? Random.secure();

  final SharedPreferences _prefs;
  final Random _random;
  static const _key = 'cbaengine.oauth_client_state.v1';

  static const notStartedHereMessage =
      "This email connection wasn't started from this app. Please connect your email again.";

  /// A fresh random value, saved for verify(). URL-safe base64 with no
  /// padding, so it passes the backend's `client_state` format check.
  Future<String> create() async {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    final value = base64Url.encode(bytes).replaceAll('=', '');
    await _prefs.setString(_key, value);
    return value;
  }

  /// Returns [result] unchanged if it may be trusted, or a failure if it's
  /// a successful connection that doesn't carry the saved value. Single
  /// use: the saved value is cleared either way, so a matching return
  /// can't be replayed later.
  Future<OAuthResult> verify(OAuthResult result) async {
    final expected = _prefs.getString(_key);
    await _prefs.remove(_key);
    if (result is OAuthSuccess && (expected == null || result.clientState != expected)) {
      return const OAuthFailure(errorCode: 'client_state_mismatch', errorDescription: notStartedHereMessage);
    }
    return result;
  }
}
