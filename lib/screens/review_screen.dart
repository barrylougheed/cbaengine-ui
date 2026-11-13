import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/message_intent.dart';
import '../providers/draft/draft_notifier.dart';
import '../providers/reference_data/reference_data_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/step_page.dart';

/// Step 4: shows the drafted message plus recipient name/party — still
/// entirely unauthenticated (councillor data comes straight from the
/// LEA picker's own GET /councils/{id}/leas response, held in
/// draftNotifier already; no email address is ever available here).
/// "Connect email and send" is the app's one explicit send confirmation — everything
/// after it (OAuth, then create -> confirm -> send) auto-chains with no
/// further tap.
///
/// The email is set out as a letter (subject as its heading, then the
/// greeting, the text and the sign-off), followed by who it goes to and the
/// consent notice for the button below.
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
    if (lea == null) return Scaffold(appBar: const AppHeader());
    final textTheme = Theme.of(context).textTheme;
    // The fixed parts the server adds around the text (greeting, sign-off).
    // Already loaded by the compose screen; if it could not be, the preview
    // simply leaves them out rather than guessing at the server's wording.
    final layout = ref.watch(topicCatalogueProvider).value?.emailLayout;
    final firstCouncillor = lea.councillors.isEmpty ? null : lea.councillors.first.name;

    return StepPage(
      step: 4,
      label: 'Review your message',
      // In a bar outside the scrolling list so the button is always on screen.
      action: FilledButton(onPressed: () => context.push('/connect'), child: const Text('Connect email and send')),
      children: [
        Text(
          '${lea.name}, ${lea.council}',
          style: textTheme.labelLarge?.copyWith(color: AppColors.linkOlive, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(switch (draft.intent) {
          MessageIntent.own => 'Written by you',
          MessageIntent.issues => 'Issues: ${draft.issues.map((issue) => issue.title).join(', ')}',
          MessageIntent.campaign => 'Campaign: ${draft.campaign?.title ?? ''}',
        }, style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText)),
        // An issues email also says which letter style it is written in.
        if (draft.intent == MessageIntent.issues && draft.style != null)
          Text('Style: ${draft.style!.title}', style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText)),
        const SizedBox(height: 16),
        // The letter: roomier than the other cards, as it is what is being sent.
        Card(
          key: const Key('review-letter'),
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(draft.subject, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const Divider(height: 32),
                if (layout != null && firstCouncillor != null) ...[
                  Text(layout.greetingFor(firstCouncillor)),
                  Text(
                    "Each councillor's own name is used in the greeting.",
                    style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(draft.body),
                const SizedBox(height: 16),
                if (layout != null) Text(layout.signOff),
                Text(draft.senderName.trim()),
                if (draft.footer != null) ...[
                  const SizedBox(height: 16),
                  Text(draft.footer!, style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'This will be sent to ${lea.councillors.length} '
          '${lea.councillors.length == 1 ? 'councillor' : 'councillors'}',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (index, councillor) in lea.councillors.indexed) ...[
                if (index > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: _Initial(index: index, name: councillor.name),
                  title: Text(councillor.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(councillor.party),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 32),
        // The explicit-consent moment (GDPR Article 9) for any
        // sensitive information in the message — see PrivacyScreen.
        DecoratedBox(
          key: const Key('review-consent'),
          decoration: BoxDecoration(
            color: AppColors.mist,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your message will be sent from your email account to these councillors, with a copy to you '
                  'and to CBAEngine so we can see whether they reply. We also keep a count of how many messages each email address has sent, '
                  'to see how the service is used. By pressing "Connect email and send", you agree to CBAEngine '
                  'processing your message, including any sensitive information in it.',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.mutedText),
                ),
                TextButton(onPressed: () => context.push('/privacy'), child: const Text('Privacy notice')),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// A councillor's initial in a soft olive disc: the avatar beside their name.
class _Initial extends StatelessWidget {
  const _Initial({required this.index, required this.name});

  final int index;
  final String name;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: Key('councillor-initial-$index'),
      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.softOlive),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: AppColors.deepOlive, fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}
