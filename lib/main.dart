import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'providers/core_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Path-based URLs (e.g. /council, not /#/council) — required so the
  // URL *fragment* is free for GET /email/callback's OAuth result
  // (token=... / error=...) instead of colliding with go_router's own
  // hash-based routing. A no-op on mobile/desktop.
  usePathUrlStrategy();

  // Captured here, before runApp() — not inside a screen's initState —
  // because go_router normalizes the browser URL against its own route
  // state during startup and commonly drops the fragment in doing so.
  // By the time any widget further down gets a chance to read
  // Uri.base.fragment, it can already be gone.
  final initialOauthFragment = kIsWeb && Uri.base.fragment.isNotEmpty ? Uri.base.fragment : null;

  // The fragment can carry a live connection token: take it out of the
  // address bar and this browser-history entry straight away, rather
  // than relying on go_router's startup happening to drop it. urlStrategy
  // is null off the web, so this is a no-op on mobile.
  final strategy = urlStrategy;
  if (initialOauthFragment != null && strategy != null) {
    strategy.replaceState(null, '', strategy.prepareExternalUrl(strategy.getPath()));
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        initialOauthFragmentProvider.overrideWith((ref) => initialOauthFragment),
      ],
      child: const CbaEngineApp(),
    ),
  );
}
