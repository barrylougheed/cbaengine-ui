import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/draft.dart';
import '../models/message_intent.dart';
import '../models/topic_catalogue.dart';
import '../models/topic_summary.dart';
import '../providers/draft/draft_notifier.dart';
import '../providers/reference_data/reference_data_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/email_editor.dart';
import '../widgets/error_banner.dart';
import '../widgets/loading_view.dart';
import '../widgets/step_page.dart';

/// Step 1, for an email about issues: choose the issues and the server writes
/// a first draft that you can edit. There is nothing to tick: choosing an issue
/// is the whole choice, and the draft appears as soon as one is chosen. Only
/// asking the server for text happens here: nothing needs the area (the text
/// never names it), and nothing is stored until the message is created after
/// the email sign-in.
class IssuesScreen extends ConsumerStatefulWidget {
  const IssuesScreen({super.key});

  @override
  ConsumerState<IssuesScreen> createState() => _IssuesScreenState();
}

class _IssuesScreenState extends ConsumerState<IssuesScreen> {
  /// True while text is being fetched.
  bool _composing = false;
  String? _composeError;

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

  /// Applies a new choice of issues (asking first when it would replace edits),
  /// and fetches the text for it.
  Future<void> _apply(List<TopicSummary> chosen) async {
    final draft = ref.read(draftNotifierProvider);
    if (draft.hasEditedText && !await _confirmDiscard('This replaces your edits. Continue?')) return;
    if (!mounted) return;

    setState(() {
      _composing = true;
      _composeError = null;
    });
    final error = await ref.read(draftNotifierProvider.notifier).chooseIssues(chosen);
    if (!mounted) return;
    setState(() {
      _composing = false;
      _composeError = error;
    });
  }

  /// Adds or removes [issue] from the chosen ones, in the catalogue's order
  /// whatever order they were chosen in.
  void _toggleIssue(TopicSummary issue, bool selected, TopicCatalogue catalogue) {
    final chosenIds = {for (final chosen in ref.read(draftNotifierProvider).issues) chosen.id};
    selected ? chosenIds.add(issue.id) : chosenIds.remove(issue.id);
    _apply([
      for (final candidate in catalogue.topics)
        if (chosenIds.contains(candidate.id)) candidate,
    ]);
  }

  Future<void> _writeMyOwn() async {
    final draft = ref.read(draftNotifierProvider);
    if (draft.hasEditedText && !await _confirmDiscard('This clears what you have written. Continue?')) return;
    if (!mounted) return;
    ref.read(draftNotifierProvider.notifier).setIntent(MessageIntent.own);
    context.pushReplacement('/craft/own');
  }

  @override
  Widget build(BuildContext context) {
    final catalogueAsync = ref.watch(topicCatalogueProvider);
    final draft = ref.watch(draftNotifierProvider);
    final textTheme = Theme.of(context).textTheme;

    // StepPage keeps Continue in a bar outside the scrolling list, so it is
    // always on screen however long the draft is (a long message otherwise
    // pushes it out of reach).
    return StepPage(
      step: 1,
      label: 'Write your message',
      action: FilledButton(
        onPressed: draft.isContentReady && !_composing ? () => context.push('/council') : null,
        child: const Text('Continue'),
      ),
      children: [
        Text('Choose the issues you care about.', style: textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'We write a first draft that asks each councillor what they are doing about it. You can change it.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
        ),
        const SizedBox(height: 16),
        catalogueAsync.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorBanner(
            message: 'Could not load the issues. Please check your connection and try again.',
            onRetry: () => ref.invalidate(topicCatalogueProvider),
          ),
          data: (catalogue) => catalogue.topics.isEmpty
              ? _NoIssuesYet(onWriteMyOwn: _writeMyOwn)
              : _IssueList(catalogue: catalogue, draft: draft, enabled: !_composing, onToggleIssue: _toggleIssue),
        ),
        if (_composing) ...[const SizedBox(height: 8), const LinearProgressIndicator()],
        if (_composeError != null) ...[const SizedBox(height: 8), ErrorBanner(message: _composeError!)],
        if (catalogueAsync.value?.topics.isNotEmpty ?? false) ...[
          const SizedBox(height: 8),
          if (!draft.selectionComplete) Text('Choose an issue to get started.', style: textTheme.bodySmall),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _composing ? null : _writeMyOwn,
              child: const Text('Want to say something different? Write your own email.'),
            ),
          ),
          const SizedBox(height: 8),
          EmailEditor(showText: draft.selectionComplete),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

/// Shown when no issue is ready yet: the resident can still write their own.
class _NoIssuesYet extends StatelessWidget {
  const _NoIssuesYet({required this.onWriteMyOwn});

  final VoidCallback onWriteMyOwn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('No issues are available yet. You can write your own email instead.'),
        const SizedBox(height: 12),
        FilledButton(onPressed: onWriteMyOwn, child: const Text('Write my own email')),
      ],
    );
  }
}

class _IssueList extends StatelessWidget {
  const _IssueList({required this.catalogue, required this.draft, required this.enabled, required this.onToggleIssue});

  final TopicCatalogue catalogue;
  final Draft draft;
  final bool enabled;
  final void Function(TopicSummary issue, bool selected, TopicCatalogue catalogue) onToggleIssue;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (index, issue) in catalogue.topics.indexed) ...[
            if (index > 0) const Divider(height: 1),
            CheckboxListTile(
              title: Text(issue.title),
              value: draft.issues.any((chosen) => chosen.id == issue.id),
              onChanged: enabled ? (checked) => onToggleIssue(issue, checked ?? false, catalogue) : null,
            ),
          ],
        ],
      ),
    );
  }
}
