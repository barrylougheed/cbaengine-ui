import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/message_intent.dart';
import '../providers/draft/draft_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/choice_card.dart';
import '../widgets/content_list.dart';

/// "Craft an email": the choice between raising issues (choose the ones you
/// care about) and writing your own. Choosing starts that kind of email; going
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

    return Scaffold(
      appBar: const AppHeader(),
      body: ContentList(
        verticalPadding: 32,
        children: [
          Text('Craft an email', style: textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Choose how you want to write to your local councillors.',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
          ),
          const SizedBox(height: 24),
          ChoiceCard(
            icon: Icons.checklist_outlined,
            title: 'Select issues',
            subtitle: 'Choose the issues you care about.',
            onTap: () => _choose(context, ref, MessageIntent.issues, '/craft/issues'),
          ),
          const SizedBox(height: 16),
          ChoiceCard(
            icon: Icons.edit_note_outlined,
            title: 'Write my own email',
            subtitle: 'Say what you think in your own words.',
            onTap: () => _choose(context, ref, MessageIntent.own, '/craft/own'),
          ),
        ],
      ),
    );
  }
}
