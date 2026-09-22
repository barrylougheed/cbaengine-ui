import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth/auth_notifier.dart';
import '../providers/draft/draft_notifier.dart';
import '../widgets/app_banner.dart';

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
      appBar: AppBar(title: const AppBanner()),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Your email connection has expired. Please reconnect your email account.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
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
    );
  }
}
