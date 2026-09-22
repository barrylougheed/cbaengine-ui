import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/app_banner.dart';

/// The app's true root — a menu of what CBAEngine can do, reached before
/// any specific flow starts. "Contact your councillors" (feature 1) is the
/// only live entry point; the second card is a placeholder for feature 3
/// (URLGeneration, see AGENTS.md) so the layout already has room for it
/// once that feature is actually specified and built, rather than needing
/// another restructure then.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppBanner()),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What would you like to do?', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Pick an option below to get started.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              _FeatureCard(
                icon: Icons.forum_outlined,
                title: 'Contact your councillors',
                subtitle: 'Draft and send a message to your local councillors.',
                onTap: () => context.push('/council'),
              ),
              const SizedBox(height: 12),
              const _FeatureCard(
                icon: Icons.link_outlined,
                title: 'Create a campaign link',
                subtitle: 'Share a pre-filled message for others to send.',
                badge: 'Coming soon',
                onTap: null,
              ),
            ],
          ),
        ),
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
