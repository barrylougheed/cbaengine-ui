import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/draft.dart';
import '../providers/draft/draft_notifier.dart';
import '../providers/reference_data/reference_data_providers.dart';
import '../widgets/app_banner.dart';
import '../widgets/step_progress_indicator.dart';

/// Step 4: shows the drafted message plus recipient name/party — still
/// entirely unauthenticated (councillor data comes straight from the
/// LEA picker's own GET /councils/{id}/leas response, held in
/// draftNotifier already; no email address is ever available here).
/// "Connect email and send" is the app's one explicit send confirmation — everything
/// after it (OAuth, then create -> confirm -> send) auto-chains with no
/// further tap.
class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(draftNotifierProvider);
    // The router guard keeps an LEA set while this screen is shown, with one
    // exception: "Start over" (the banner's dialog) empties the draft while
    // this screen is still animating away, which rebuilds it one last time.
    // Show just the app bar for those few frames rather than fail to build.
    final lea = draft.lea;
    if (lea == null) return Scaffold(appBar: AppBar(title: const AppBanner()));
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    // The fixed parts the server adds around the text (greeting, sign-off).
    // Already loaded by the compose screen; if it could not be, the preview
    // simply leaves them out rather than guessing at the server's wording.
    final layout = ref.watch(topicCatalogueProvider).value?.emailLayout;
    final firstCouncillor = lea.councillors.isEmpty ? null : lea.councillors.first.name;

    return Scaffold(
      appBar: AppBar(title: const AppBanner()),
      body: Column(
        children: [
          const StepProgressIndicator(currentStep: 4, totalSteps: 5, label: 'Review your message'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Text('${lea.name}, ${lea.council}', style: textTheme.labelLarge?.copyWith(color: colorScheme.primary)),
                const SizedBox(height: 2),
                Text(
                  draft.mode == ComposeMode.ownWords
                      ? 'Written by you'
                      : 'Topics: ${draft.topics.map((topic) => topic.title).join(', ')}',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(draft.subject, style: textTheme.titleLarge),
                        const SizedBox(height: 8),
                        if (layout != null && firstCouncillor != null) ...[
                          Text(layout.greetingFor(firstCouncillor)),
                          Text(
                            "Each councillor's own name is used in the greeting.",
                            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(draft.body),
                        const SizedBox(height: 12),
                        if (layout != null) Text(layout.signOff),
                        Text(draft.senderName.trim()),
                        if (draft.footer != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            draft.footer!,
                            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
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
                // The explicit-consent moment (GDPR Article 9) for any
                // sensitive information in the message — see PrivacyScreen.
                Text(
                  'Your message will be sent from your email account to these councillors, with a copy to you '
                  'and to CBAEngine so we can see whether they reply. We also keep a count of how many messages each email address has sent, '
                  'to see how the service is used. By pressing "Connect email and send", you agree to CBAEngine '
                  'processing your message, including any sensitive information in it.',
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(onPressed: () => context.push('/privacy'), child: const Text('Privacy notice')),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          // Outside the scrolling list so the button is always on screen.
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.push('/connect'),
                  child: const Text('Connect email and send'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
