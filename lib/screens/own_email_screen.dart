import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/draft/draft_notifier.dart';
import '../widgets/app_banner.dart';
import '../widgets/email_editor.dart';
import '../widgets/step_progress_indicator.dart';

/// Step 1, for an email in the resident's own words: their subject and
/// message, and a name for the sign-off. It is where to say what the issue
/// proposals do not cover, including views that differ from them. Nothing here
/// needs the area, and there is no footer: nothing started from a template.
class OwnEmailScreen extends ConsumerWidget {
  const OwnEmailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(draftNotifierProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const AppBanner()),
      body: Column(
        children: [
          const StepProgressIndicator(currentStep: 1, totalSteps: 5, label: 'Write your message'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Text(
                  'Say what you think in your own words, including views the issue proposals do not cover.',
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                const EmailEditor(),
                const SizedBox(height: 16),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: draft.isContentReady ? () => context.push('/council') : null,
                  child: const Text('Continue'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
