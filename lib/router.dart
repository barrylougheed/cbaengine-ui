import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'models/message_intent.dart';
import 'providers/auth/auth_notifier.dart';
import 'providers/auth/auth_state.dart';
import 'providers/draft/draft_notifier.dart';
import 'screens/campaign_email_screen.dart';
import 'screens/campaigns_screen.dart';
import 'screens/connect_email_screen.dart';
import 'screens/council_picker_screen.dart';
import 'screens/craft_screen.dart';
import 'screens/find_area_screen.dart';
import 'screens/home_screen.dart';
import 'screens/issues_screen.dart';
import 'screens/lea_picker_screen.dart';
import 'screens/own_email_screen.dart';
import 'screens/privacy_screen.dart';
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
///
/// The order of the steps: the email first (`/craft/issues`, `/craft/own`, or
/// a campaign's `/campaigns/email`), then the council, the area, and Review.
final routerProvider = Provider<GoRouter>((ref) {
  final authRefresh = _AuthRefreshListenable(ref);

  return GoRouter(
    initialLocation: '/',
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
      if (goingTo == '/craft/own' && draft.intent != MessageIntent.own) return '/craft';
      if (goingTo == '/craft/issues' && draft.intent != MessageIntent.issues) return '/craft';
      if (goingTo == '/campaigns/email' && draft.campaign == null) return '/campaigns';

      // The council and area come after the email: it has to be finished first.
      final choosingWhere = goingTo == '/council' || goingTo == '/find-area' || goingTo.startsWith('/council/');
      if (choosingWhere && !draft.isContentReady) return '/';
      if (goingTo == '/review') {
        if (!draft.isContentReady) return '/';
        if (draft.lea == null) return '/council';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(path: '/craft', builder: (context, state) => const CraftScreen()),
      GoRoute(path: '/craft/issues', builder: (context, state) => const IssuesScreen()),
      GoRoute(path: '/craft/own', builder: (context, state) => const OwnEmailScreen()),
      GoRoute(path: '/campaigns', builder: (context, state) => const CampaignsScreen()),
      GoRoute(path: '/campaigns/email', builder: (context, state) => const CampaignEmailScreen()),
      GoRoute(path: '/council', builder: (context, state) => const CouncilPickerScreen()),
      GoRoute(path: '/find-area', builder: (context, state) => const FindAreaScreen()),
      GoRoute(
        path: '/council/:councilId/lea',
        builder: (context, state) => LeaPickerScreen(councilId: state.pathParameters['councilId']!),
      ),
      GoRoute(path: '/review', builder: (context, state) => const ReviewScreen()),
      GoRoute(path: '/connect', builder: (context, state) => const ConnectEmailScreen()),
      GoRoute(path: '/result', builder: (context, state) => const ResultScreen()),
      GoRoute(path: '/reconnect', builder: (context, state) => const ReconnectScreen()),
      GoRoute(path: '/privacy', builder: (context, state) => const PrivacyScreen()),
    ],
  );
});
