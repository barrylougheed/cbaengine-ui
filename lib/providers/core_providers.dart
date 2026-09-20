import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../config/app_config.dart';
import '../services/draft_storage_service.dart';
import '../services/oauth_service.dart';
import 'auth/auth_notifier.dart';

final httpClientProvider = Provider<http.Client>((ref) => http.Client());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    httpClient: ref.watch(httpClientProvider),
    baseUrl: apiBaseUrl,
    getToken: () => ref.read(authNotifierProvider).token,
    onUnauthorized: () => ref.read(authNotifierProvider.notifier).markExpired(),
  );
});

/// Overridden in main() with the real instance obtained via
/// SharedPreferences.getInstance() before runApp — that call is async,
/// so it can't happen inside a synchronous Provider body.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in main() before runApp.');
});

final draftStorageServiceProvider = Provider<DraftStorageService>((ref) {
  return DraftStorageService(ref.watch(sharedPreferencesProvider));
});

final oauthServiceProvider = Provider<OAuthService>((ref) {
  return OAuthService(ref.watch(apiClientProvider));
});

/// The URL fragment captured in main() *before* runApp() — go_router
/// normalizes the browser URL during its own startup (reconciling its
/// internal route state with window.location) and commonly strips the
/// fragment in the process, so reading Uri.base.fragment from anywhere
/// inside the widget tree (even in a screen's initState/post-frame
/// callback) can already be too late. Overridden with the real captured
/// value in main(); null on non-web or when there was nothing to
/// capture. A StateProvider so ConnectEmailScreen can consume (null out)
/// the value once it's handled it, so navigating back to /connect later
/// in the same session never reprocesses a stale fragment.
final initialOauthFragmentProvider = StateProvider<String?>((ref) => null);
