import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth/auth_notifier.dart';
import '../providers/draft/draft_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/content_width.dart';

/// Reached from anywhere the moment authNotifierProvider reports an
/// expired session (a 401 from any authenticated call) — the router's
/// global redirect guard sends the user here regardless of what screen
/// they were on. The draft at that point is stale/likely partially
/// consumed server-side already, so "reconnect" here means starting the
/// area-selection flow over, not resuming mid-draft.
class ReconnectScreen extends ConsumerWidget {
  const ReconnectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const AppHeader(),
      // Centred in the window, in the same reading column as the steps.
      body: Center(
        child: SingleChildScrollView(
          child: ContentWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link_off, size: 48, color: AppColors.clay),
                const SizedBox(height: 16),
                Text(
                  'Your email connection has expired. Please reconnect your email account.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    ref.read(authNotifierProvider.notifier).signOut();
                    ref.read(draftNotifierProvider.notifier).clear();
                    context.go('/');
                  },
                  child: const Text('Start again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
