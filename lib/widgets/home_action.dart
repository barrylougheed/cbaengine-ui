import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/draft/draft_notifier.dart';

/// AppBar action, consistent across every step screen except the
/// council picker itself (already home): discards the in-progress
/// draft and returns to the start. Confirms first — unlike the
/// automatic back arrow (which just steps back one screen, keeping
/// everything typed so far), this can throw away a drafted message.
class HomeAction extends ConsumerWidget {
  const HomeAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.home_outlined),
      tooltip: 'Start over',
      onPressed: () => _confirmAndGoHome(context, ref),
    );
  }

  static Future<void> _confirmAndGoHome(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start over?'),
        content: const Text('Your drafted message will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Start over')),
        ],
      ),
    );
    if (confirmed != true) return;
    ref.read(draftNotifierProvider.notifier).clear();
    if (context.mounted) context.go('/council');
  }
}
