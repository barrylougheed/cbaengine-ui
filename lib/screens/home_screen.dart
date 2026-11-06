import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/reference_data/reference_data_providers.dart';
import '../utils/counts.dart';
import '../widgets/app_banner.dart';

/// The app's true root — a menu of what CBAEngine can do, reached before
/// any specific flow starts. "Craft an email" (issues, or your own words) and
/// "Campaigns" are the live entry points (feature 1); the third card is a
/// placeholder for feature 3 (URLGeneration, see AGENTS.md) so the layout
/// already has room for it once that feature is actually specified and built,
/// rather than needing another restructure then.
///
/// Below the cards it says, before anyone starts, that one email can be sent a
/// day, how many councillors can be written to, how the flow works, and which
/// email accounts can send (so an iCloud or Yahoo user does not find out at the
/// last step).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    // Loading or failing to load the councils only costs the total below.
    final councils = ref.watch(councilsProvider).value ?? const [];
    final totalCouncillors = councils.fold<int>(0, (sum, council) => sum + council.councillorCount);

    return Scaffold(
      appBar: AppBar(title: const AppBanner()),
      body: SafeArea(
        child: Column(
          children: [
            // The content scrolls; the footer below stays put, so nothing has
            // to be measured to keep it at the bottom.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hold yourself accountable for holding power accountable.',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontStyle: FontStyle.italic, color: colorScheme.primary),
                    ),
                    const SizedBox(height: 24),
                    Text('What would you like to do?', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      'Pick an option below to get started.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 24),
                    _FeatureCard(
                      icon: Icons.edit_outlined,
                      title: 'Craft an email',
                      subtitle: 'Raise issues with your local councillors, or write your own message.',
                      onTap: () => context.push('/craft'),
                    ),
                    const SizedBox(height: 12),
                    _FeatureCard(
                      icon: Icons.campaign_outlined,
                      title: 'Campaigns',
                      subtitle: 'Back a campaign by emailing your local councillors.',
                      onTap: () => context.push('/campaigns'),
                    ),
                    const SizedBox(height: 12),
                    const _FeatureCard(
                      icon: Icons.link_outlined,
                      title: 'Create a campaign link',
                      subtitle: 'Share a pre-filled message for others to send.',
                      badge: 'Coming soon',
                      onTap: null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 18, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        const Expanded(child: Text('You can send one email a day.')),
                      ],
                    ),
                    if (totalCouncillors > 0) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Write to any of ${countOf(totalCouncillors, 'councillor')} across ${countOf(councils.length, 'council')}.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text('How it works', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const _Step(number: 1, text: 'Craft an email, or back a campaign.'),
                    const _Step(
                      number: 2,
                      text: 'Choose your council and area, then review your message and who it goes to.',
                    ),
                    const _Step(
                      number: 3,
                      text:
                          'Connect your Gmail or Outlook account. Your message is sent straight away, from your own account, with a copy to you.',
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 18, color: colorScheme.primary),
                        const SizedBox(width: 8),
                        const Expanded(child: Text("You'll need a Gmail, Outlook or Hotmail account to send.")),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const _SocialLinks(),
            TextButton(onPressed: () => context.push('/privacy'), child: const Text('Privacy notice')),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
            child: Text('$number', style: Theme.of(context).textTheme.labelSmall),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.icon, required this.title, required this.subtitle, this.badge, this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;

    return Card(
      child: ListTile(
        enabled: enabled,
        onTap: onTap,
        leading: Icon(icon, color: enabled ? colorScheme.primary : null),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: badge != null
            ? Chip(label: Text(badge!), visualDensity: VisualDensity.compact)
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}

/// Not live accounts yet — icons are shown so the footer's final shape is
/// already in place, but deliberately inert (disabled `IconButton`s, no
/// `onTap`) rather than linking anywhere until real accounts exist.
class _SocialLinks extends StatelessWidget {
  const _SocialLinks();

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'Instagram — coming soon',
          child: IconButton(icon: Icon(Icons.camera_alt_outlined, color: mutedColor), onPressed: null),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'YouTube — coming soon',
          child: IconButton(icon: Icon(Icons.smart_display_outlined, color: mutedColor), onPressed: null),
        ),
      ],
    );
  }
}
