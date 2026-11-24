import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/message_record.dart';
import '../models/message_status.dart';
import '../providers/draft/draft_notifier.dart';
import '../providers/message_flow/message_flow_notifier.dart';
import '../providers/message_flow/message_flow_state.dart';
import '../theme/app_theme.dart';
import '../utils/counts.dart';
import '../widgets/app_header.dart';
import '../widgets/content_width.dart';
import '../widgets/footer_scroll.dart';

/// Step 6, terminal: renders MessageRecord.status/.detail verbatim
/// against the backend's exact wording — sent, failed, or partial
/// failure. Never a toast; this is the flow's actual outcome, reached
/// automatically once ConnectEmailScreen's auto-chain (create -> confirm
/// -> send) settles.
class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(messageFlowNotifierProvider);

    return Scaffold(
      appBar: const AppHeader(),
      // Centred in the space above the footer, in the same reading column as the steps before it.
      body: FooterScroll(
        centered: true,
        child: ContentWidth(
          child: Padding(padding: const EdgeInsets.symmetric(vertical: 32), child: _body(context, ref, state)),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, MessageFlowState state) {
    final isTerminal = state is MessageFlowResult || state is MessageFlowFailed;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        switch (state) {
          MessageFlowIdle() ||
          MessageFlowCreating() ||
          MessageFlowConfirming() ||
          MessageFlowSending() => const CircularProgressIndicator(),
          MessageFlowResult(:final record) when record.status == MessageStatus.sent => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _AnimatedOutcomeIcon(icon: Icons.check_circle_outline, color: AppColors.success),
              const SizedBox(height: 16),
              Text('Your message was sent.', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 24),
              _SentTo(record),
            ],
          ),
          MessageFlowResult(:final record) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AnimatedOutcomeIcon(icon: Icons.error_outline, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text('Your message could not be sent.', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              if (record.detail != null) Text(record.detail!, textAlign: TextAlign.center),
            ],
          ),
          MessageFlowFailed(:final failure) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AnimatedOutcomeIcon(icon: Icons.error_outline, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(failure.message, textAlign: TextAlign.center),
            ],
          ),
        },
        // The flow's actual end — nothing to lose by leaving from here,
        // so this resets straight away with no confirmation (unlike
        // AppBanner, used on every earlier screen, which can discard an
        // in-progress draft and does confirm).
        if (isTerminal) ...[
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () {
              ref.read(draftNotifierProvider.notifier).clear();
              context.go('/');
            },
            child: const Text('Back to start'),
          ),
        ],
      ],
    );
  }
}

/// Who a sent message went to, and where the copy and any replies land.
///
/// A message is only ever `sent` when every councillor on the record received
/// it (a partial delivery is `failed`, with the API's own explanation), so the
/// record's councillors are exactly who it reached. Names and parties only:
/// their email addresses are not shown to the resident (as on Review).
class _SentTo extends StatelessWidget {
  const _SentTo(this.record);

  final MessageRecord record;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // As wide as the column (the screen's Column would otherwise shrink it to
    // its widest line).
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (record.councillors.isNotEmpty) ...[
            Text(
              'Sent to ${countOf(record.councillors.length, 'councillor')}',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (index, councillor) in record.councillors.indexed) ...[
                    if (index > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.check_circle, color: AppColors.success, size: 24),
                      title: Text(councillor.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(councillor.party),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            'A copy has been sent to ${record.sender}, and any replies will come to that inbox.',
            style: textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
          ),
        ],
      ),
    );
  }
}

/// A small scale + fade entrance for the terminal outcome icon — the one
/// place in the app that earns a bit of motion, since it's the payoff
/// moment of the whole flow.
class _AnimatedOutcomeIcon extends StatelessWidget {
  const _AnimatedOutcomeIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.scale(scale: value, child: child),
        );
      },
      child: Icon(icon, color: color, size: 56),
    );
  }
}
