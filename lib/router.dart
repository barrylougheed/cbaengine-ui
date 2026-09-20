import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'providers/auth/auth_notifier.dart';
import 'providers/auth/auth_state.dart';
import 'providers/draft/draft_notifier.dart';
import 'screens/compose_screen.dart';
import 'screens/connect_email_screen.dart';
import 'screens/council_picker_screen.dart';
import 'screens/lea_picker_screen.dart';
import 'screens/reconnect_screen.dart';
import 'screens/result_screen.dart';
import 'screens/review_screen.dart';

/// Bridges authNotifierProvider's changes into something GoRouter can
/// listen to — without this, `redirect` only re-runs on an active
/// navigation, so a 401 that happens mid-flow (not from a nav attempt)
/// wouldn't bounce the user to /reconnect until they next tapped
/// something. This is what makes markExpired() a true "from anywhere"
/// choke point rather than a best-effort one.
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(Ref ref) {
    ref.listen(authNotifierProvider, (previous, next) => notifyListeners());
  }
}

/// The app's whole route table, plus its guards. A Provider (not a
/// bare GoRouter) so `redirect` can read draftNotifierProvider and
/// authNotifierProvider directly.
final routerProvider = Provider<GoRouter>((ref) {
  final authRefresh = _AuthRefreshListenable(ref);

  return GoRouter(
    initialLocation: '/council',
    refreshListenable: authRefresh,
    redirect: (context, state) {
      final goingTo = state.matchedLocation;

      // Global rule: any expired session bounces to /reconnect from
      // anywhere, regardless of what triggered it.
      if (ref.read(authNotifierProvider).status == AuthStatus.expired && goingTo != '/reconnect') {
        return '/reconnect';
      }

      // Skipping straight to a later step via a raw URL bounces back to
      // wherever the flow actually is, rather than showing a screen
      // with nothing to work from. /connect is deliberately unguarded:
      // after a web OAuth round-trip reloads the app, draftNotifier's
      // in-memory state is gone, but ConnectEmailScreen itself restores
      // from persisted storage — a naive draft-based guard here would
      // incorrectly bounce that legitimate return trip away.
      final draft = ref.read(draftNotifierProvider);
      if (goingTo == '/compose' && draft.lea == null) return '/council';
      if (goingTo == '/review' && !draft.isReadyToReview) return '/compose';
      return null;
    },
    routes: [
      GoRoute(path: '/council', builder: (context, state) => const CouncilPickerScreen()),
      GoRoute(
        path: '/council/:councilId/lea',
        builder: (context, state) => LeaPickerScreen(councilId: state.pathParameters['councilId']!),
      ),
      GoRoute(path: '/compose', builder: (context, state) => const ComposeScreen()),
      GoRoute(path: '/review', builder: (context, state) => const ReviewScreen()),
      GoRoute(path: '/connect', builder: (context, state) => const ConnectEmailScreen()),
      GoRoute(path: '/result', builder: (context, state) => const ResultScreen()),
      GoRoute(path: '/reconnect', builder: (context, state) => const ReconnectScreen()),
    ],
  );
});
