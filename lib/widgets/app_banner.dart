import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/draft/draft_notifier.dart';

/// The app's persistent brand mark — top-left on every screen, the same
/// place most web services (Gmail, GitHub, Notion, ...) put a logo that
/// doubles as the link back to the start, rather than a separate icon
/// tucked in the corner. Sits in the AppBar's `title` slot, immediately
/// after the automatic back arrow when there's one — the theme already
/// left-aligns titles (`centerTitle: false`), so no extra positioning
/// work is needed to land it top-left.
///
/// Consistency principle: identical on every screen, including the
/// terminal Result/Reconnect screens — always the same place, always
/// the same behaviour.
class AppBanner extends ConsumerWidget {
  const AppBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    // Already home: tapping the brand mark is a no-op on every site that
    // has one, not a chance to "lose" a draft that isn't being navigated
    // away from — skip the confirmation dialog entirely rather than
    // prompting over stale draft state left behind by a plain back-arrow
    // return to this screen.
    final isHome = GoRouterState.of(context).matchedLocation == '/';
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: isHome ? null : () => _confirmAndGoHome(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, color: colorScheme.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              'CBAEngine',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _confirmAndGoHome(BuildContext context, WidgetRef ref) async {
    final draft = ref.read(draftNotifierProvider);
    final hasProgress =
        draft.council != null || draft.lea != null || draft.subject.isNotEmpty || draft.body.isNotEmpty;

    // Nothing at stake yet (e.g. tapped from a fresh screen) — skip the
    // nag. Confirming is only meaningful when there's actually something
    // to lose; the rule itself is applied consistently even though the
    // outcome varies.
    if (!hasProgress) {
      context.go('/');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dialogColorScheme = Theme.of(dialogContext).colorScheme;
        return AlertDialog(
          title: const Text('Start over?'),
          content: const Text('Your drafted message will be lost.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            // Contrast principle: a destructive action shouldn't look
            // like an ordinary primary one — styled with the theme's
            // error color rather than FilledButton's default.
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: dialogColorScheme.error,
                foregroundColor: dialogColorScheme.onError,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Start over'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    ref.read(draftNotifierProvider.notifier).clear();
    if (context.mounted) context.go('/');
  }
}
