import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/draft/draft_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/email_editor.dart';
import '../widgets/step_page.dart';

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
    if (campaign == null) return Scaffold(appBar: const AppHeader());

    return StepPage(
      step: 1,
      label: 'Write your message',
      action: FilledButton(
        onPressed: draft.isContentReady ? () => context.push('/council') : null,
        child: const Text('Continue'),
      ),
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: ListTile(title: Text(campaign.title), subtitle: Text(campaign.summary)),
        ),
        const SizedBox(height: 12),
        Text(
          'We write a first draft for this campaign. You can change it before you send.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
        ),
        const SizedBox(height: 16),
        const EmailEditor(),
        const SizedBox(height: 16),
      ],
    );
  }
}
