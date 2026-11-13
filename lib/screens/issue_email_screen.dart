import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/draft/draft_notifier.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/email_editor.dart';
import '../widgets/issue_choice_summary.dart';
import '../widgets/step_page.dart';

/// The last part of the first step for an email about issues: the text the
/// server wrote for the topics and style chosen, which the resident can edit,
/// and their name. A summary says what the email is about and in what style,
/// with a link to change either (changing asks first when the text has been
/// edited). Nothing here needs an area, and the router only opens it once the
/// text has been written.
class IssueEmailScreen extends ConsumerWidget {
  const IssueEmailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(draftNotifierProvider);
    // "Start over" (the header's dialog) empties the draft while this screen is
    // still animating away, which rebuilds it one last time: show just the
    // header for those few frames rather than fail to build.
    if (!draft.selectionComplete) return const Scaffold(appBar: AppHeader());

    return StepPage(
      step: 1,
      label: 'Write your message',
      // Outside the scrolling list, so Continue is always on screen however
      // long the draft is (a long message otherwise pushes it out of reach).
      action: FilledButton(
        onPressed: draft.isContentReady ? () => context.push('/council') : null,
        child: const Text('Continue'),
      ),
      children: [
        Text(
          'We write a first draft that asks each councillor what they are doing about it. You can change it.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
        ),
        const SizedBox(height: 12),
        IssueChoiceSummary(
          topics: draft.issues,
          style: draft.style,
          onChangeTopics: () => context.push('/craft/issues'),
          onChangeStyle: () => context.push('/craft/issues/style'),
        ),
        const SizedBox(height: 16),
        const EmailEditor(),
        const SizedBox(height: 16),
      ],
    );
  }
}
