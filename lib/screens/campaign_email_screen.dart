import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/draft/draft_notifier.dart';
import '../widgets/app_banner.dart';
import '../widgets/email_editor.dart';
import '../widgets/step_progress_indicator.dart';

/// Step 1, for a campaign: the email the server wrote for the chosen campaign,
/// which the resident can edit, and their name. The router's guard keeps a
/// campaign chosen while this screen is shown.
class CampaignEmailScreen extends ConsumerWidget {
  const CampaignEmailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(draftNotifierProvider);
    // "Start over" (the banner's dialog) empties the draft while this screen is
    // still animating away, which rebuilds it one last time: show just the app
    // bar for those few frames rather than fail to build.
    final campaign = draft.campaign;
    if (campaign == null) return Scaffold(appBar: AppBar(title: const AppBanner()));
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
                Card(
                  child: ListTile(
                    title: Text(campaign.title),
                    subtitle: Text(campaign.summary),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We write a first draft for this campaign. You can change it before you send.',
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
