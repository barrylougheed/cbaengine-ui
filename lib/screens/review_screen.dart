import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/draft/draft_notifier.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Review your message')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${lea.name}, ${lea.council}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Topic: ${draft.topic}'),
          const SizedBox(height: 16),
          Text(draft.subject, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(draft.body),
          const SizedBox(height: 24),
          Text(
            'This will be sent to ${lea.councillors.length} '
            '${lea.councillors.length == 1 ? 'councillor' : 'councillors'}:',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          for (final councillor in lea.councillors)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(councillor.name),
              subtitle: Text(councillor.party),
            ),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => context.go('/connect'), child: const Text('Continue')),
        ],
      ),
    );
  }
}
