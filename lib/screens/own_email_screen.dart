import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/draft/draft_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/email_editor.dart';
import '../widgets/step_page.dart';

/// Step 1, for an email in the resident's own words: their subject and
/// message, and a name for the sign-off. It is where to say what the issues
/// do not cover, including views that differ from them. Nothing here
/// needs the area, and there is no footer: nothing started from a template.
class OwnEmailScreen extends ConsumerWidget {
  const OwnEmailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(draftNotifierProvider);

    return StepPage(
      step: 1,
      label: 'Write your message',
      action: FilledButton(
        onPressed: draft.isContentReady ? () => context.push('/council') : null,
        child: const Text('Continue'),
      ),
      children: [
        Text(
          'Say what you think in your own words, including views the issues do not cover.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
        ),
        const SizedBox(height: 16),
        const EmailEditor(),
        const SizedBox(height: 16),
      ],
    );
  }
}
