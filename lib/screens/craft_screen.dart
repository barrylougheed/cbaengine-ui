import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/message_intent.dart';
import '../providers/draft/draft_notifier.dart';
import '../widgets/app_banner.dart';

/// "Craft an email": the choice between raising issues (tick the proposals you
/// support) and writing your own. Choosing starts that kind of email; going
/// back and choosing the other asks first when there is text that would be lost.
class CraftScreen extends ConsumerWidget {
  const CraftScreen({super.key});

  Future<bool> _confirmDiscard(BuildContext context, String message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Continue')),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _choose(BuildContext context, WidgetRef ref, MessageIntent intent, String route) async {
    final draft = ref.read(draftNotifierProvider);
    if (intent != draft.intent &&
        draft.hasEditedText &&
        !await _confirmDiscard(context, 'This clears what you have written. Continue?')) {
      return;
    }
    if (!context.mounted) return;
    ref.read(draftNotifierProvider.notifier).setIntent(intent);
    context.push(route);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const AppBanner()),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Craft an email', style: textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Choose how you want to write to your local councillors.',
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Card(
            child: ListTile(
              leading: Icon(Icons.checklist_outlined, color: colorScheme.primary),
              title: const Text('Select issues'),
              subtitle: const Text('Choose issues you care about and tick the proposals you support.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _choose(context, ref, MessageIntent.issues, '/craft/issues'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.edit_note_outlined, color: colorScheme.primary),
              title: const Text('Write my own email'),
              subtitle: const Text('Say what you think in your own words.'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _choose(context, ref, MessageIntent.own, '/craft/own'),
            ),
          ),
        ],
      ),
    );
  }
}
