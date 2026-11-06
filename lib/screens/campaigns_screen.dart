import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/campaign_summary.dart';
import '../models/message_intent.dart';
import '../providers/draft/draft_notifier.dart';
import '../providers/reference_data/reference_data_providers.dart';
import '../widgets/app_banner.dart';
import '../widgets/error_banner.dart';
import '../widgets/loading_view.dart';

/// The campaigns a resident can back. Choosing one fetches the email written for
/// it and opens it for editing; the email then goes to the resident's own area
/// councillors like any other. Going back and choosing a different campaign
/// asks first when there are edits that would be replaced.
class CampaignsScreen extends ConsumerStatefulWidget {
  const CampaignsScreen({super.key});

  @override
  ConsumerState<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends ConsumerState<CampaignsScreen> {
  bool _loading = false;
  String? _error;

  Future<bool> _confirmDiscard(String message) async {
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

  Future<void> _choose(CampaignSummary campaign) async {
    final draft = ref.read(draftNotifierProvider);

    // The same campaign again: back to the email as it was, edits and all.
    if (draft.intent == MessageIntent.campaign && draft.campaign?.id == campaign.id) {
      context.push('/campaigns/email');
      return;
    }
    if (draft.hasEditedText) {
      final message = draft.intent == MessageIntent.campaign
          ? 'This replaces your edits. Continue?'
          : 'This clears what you have written. Continue?';
      if (!await _confirmDiscard(message)) return;
    }
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    final notifier = ref.read(draftNotifierProvider.notifier);
    notifier.setIntent(MessageIntent.campaign);
    final error = await notifier.chooseCampaign(campaign);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = error;
    });
    if (error == null) context.push('/campaigns/email');
  }

  Future<void> _learnMore(String link) async {
    await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final campaignsAsync = ref.watch(campaignsProvider);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const AppBanner()),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Choose a campaign to back.', style: textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Your email goes to your own area councillors, whichever campaign you choose. '
            'You can change it before you send.',
            style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          campaignsAsync.when(
            loading: () => const LoadingView(),
            error: (error, _) => ErrorBanner(
              message: 'Could not load the campaigns. Please check your connection and try again.',
              onRetry: () => ref.invalidate(campaignsProvider),
            ),
            data: (campaigns) => campaigns.isEmpty
                ? const Text('No campaigns are open yet.')
                : Column(
                    children: [
                      for (final campaign in campaigns)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ListTile(
                                  enabled: !_loading,
                                  title: Text(campaign.title),
                                  subtitle: Text(campaign.summary),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: _loading ? null : () => _choose(campaign),
                                ),
                                if (campaign.link != null)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: TextButton(
                                      onPressed: () => _learnMore(campaign.link!),
                                      child: const Text('Learn more'),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          if (_loading) ...[const SizedBox(height: 8), const LinearProgressIndicator()],
          if (_error != null) ...[const SizedBox(height: 8), ErrorBanner(message: _error!)],
        ],
      ),
    );
  }
}
