import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/draft/draft_notifier.dart';
import '../widgets/app_banner.dart';
import '../widgets/step_progress_indicator.dart';

/// Step 4: shows the drafted message plus recipient name/party — still
/// entirely unauthenticated (councillor data comes straight from the
/// LEA picker's own GET /councils/{id}/leas response, held in
/// draftNotifier already; no email address is ever available here).
/// "Continue" is the app's one explicit send confirmation — everything
/// after it (OAuth, then create -> confirm -> send) auto-chains with no
/// further tap.
class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(draftNotifierProvider);
    final lea = draft.lea!; // router guard guarantees this is set
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const AppBanner()),
      body: Column(
        children: [
          const StepProgressIndicator(currentStep: 4, totalSteps: 5, label: 'Review your message'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Text(
                  '${lea.name}, ${lea.council}',
                  style: textTheme.labelLarge?.copyWith(color: colorScheme.primary),
                ),
                const SizedBox(height: 2),
                Text('Topic: ${draft.topic}', style: textTheme.bodySmall),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(draft.subject, style: textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(draft.body),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'This will be sent to ${lea.councillors.length} '
                  '${lea.councillors.length == 1 ? 'councillor' : 'councillors'}',
                  style: textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final (index, councillor) in lea.councillors.indexed) ...[
                        if (index > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: colorScheme.primaryContainer,
                            foregroundColor: colorScheme.onPrimaryContainer,
                            child: Text(councillor.name.isNotEmpty ? councillor.name[0] : '?'),
                          ),
                          title: Text(councillor.name),
                          subtitle: Text(councillor.party),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: () => context.push('/connect'), child: const Text('Continue')),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
