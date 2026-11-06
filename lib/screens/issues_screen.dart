import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/draft.dart';
import '../models/message_intent.dart';
import '../models/topic_catalogue.dart';
import '../models/topic_summary.dart';
import '../providers/draft/draft_notifier.dart';
import '../providers/reference_data/reference_data_providers.dart';
import '../widgets/app_banner.dart';
import '../widgets/email_editor.dart';
import '../widgets/error_banner.dart';
import '../widgets/loading_view.dart';
import '../widgets/step_progress_indicator.dart';

/// Step 1, for an email about issues: choose the issues, tick the proposals you
/// support, and the server writes a first draft that you can edit. The draft
/// only appears once every chosen issue has a proposal ticked. Only asking the
/// server for text happens here: nothing needs the area (the text never names
/// it), and nothing is stored until the message is created after the email
/// sign-in.
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

  /// Applies a new choice of issues and ticks (asking first when it would
  /// replace edits), and fetches the text for it.
  Future<void> _apply(List<TopicSummary> chosen, Map<String, List<String>> ticked) async {
    final draft = ref.read(draftNotifierProvider);
    if (draft.hasEditedText && !await _confirmDiscard('This replaces your edits. Continue?')) return;
    if (!mounted) return;

    setState(() {
      _composing = true;
      _composeError = null;
    });
    final error = await ref.read(draftNotifierProvider.notifier).chooseIssues(chosen, ticked);
    if (!mounted) return;
    setState(() {
      _composing = false;
      _composeError = error;
    });
  }

  /// The ticks as they stand, to change one of them.
  Map<String, List<String>> _currentTicks() {
    final draft = ref.read(draftNotifierProvider);
    return {
      for (final issue in draft.issues) issue.id: [...?draft.ticked[issue.id]],
    };
  }

  /// The issues with an entry in [ticked], in the catalogue's order whatever
  /// order they were chosen in.
  List<TopicSummary> _chosenIn(Map<String, List<String>> ticked, TopicCatalogue catalogue) => [
    for (final issue in catalogue.topics)
      if (ticked.containsKey(issue.id)) issue,
  ];

  void _toggleIssue(TopicSummary issue, bool selected, TopicCatalogue catalogue) {
    final ticked = _currentTicks();
    if (selected) {
      ticked.putIfAbsent(issue.id, () => []);
    } else {
      ticked.remove(issue.id);
    }
    _apply(_chosenIn(ticked, catalogue), ticked);
  }

  void _toggleProposal(TopicSummary issue, ProposalSummary proposal, bool selected, TopicCatalogue catalogue) {
    final ticked = _currentTicks();
    final proposals = ticked.putIfAbsent(issue.id, () => []);
    selected ? proposals.add(proposal.id) : proposals.remove(proposal.id);
    _apply(_chosenIn(ticked, catalogue), ticked);
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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const AppBanner()),
      body: Column(
        children: [
          const StepProgressIndicator(currentStep: 1, totalSteps: 5, label: 'Write your message'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Text('Choose the issues you care about, then tick the proposals you support.', style: textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Each councillor will be asked whether they would support what you tick. '
                  'We write a first draft that you can change.',
                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                catalogueAsync.when(
                  loading: () => const LoadingView(),
                  error: (error, _) => ErrorBanner(
                    message: 'Could not load the issues. Please check your connection and try again.',
                    onRetry: () => ref.invalidate(topicCatalogueProvider),
                  ),
                  data: (catalogue) => catalogue.topics.isEmpty
                      ? _NoIssuesYet(onWriteMyOwn: _writeMyOwn)
                      : _IssueList(
                          catalogue: catalogue,
                          draft: draft,
                          enabled: !_composing,
                          onToggleIssue: _toggleIssue,
                          onToggleProposal: _toggleProposal,
                        ),
                ),
                if (_composing) ...[const SizedBox(height: 8), const LinearProgressIndicator()],
                if (_composeError != null) ...[const SizedBox(height: 8), ErrorBanner(message: _composeError!)],
                if (catalogueAsync.value?.topics.isNotEmpty ?? false) ...[
                  const SizedBox(height: 8),
                  if (!draft.selectionComplete)
                    Text(
                      draft.issues.isEmpty
                          ? 'Choose an issue to get started.'
                          : 'Tick at least one proposal for each issue to see your email.',
                      style: textTheme.bodySmall,
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: _composing ? null : _writeMyOwn,
                      child: const Text('Disagree with these? Write your own email.'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  EmailEditor(showText: draft.selectionComplete),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
          // Outside the scrolling list, so Continue is always on screen however
          // long the draft is (a long message otherwise pushes it out of reach).
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: draft.isContentReady && !_composing ? () => context.push('/council') : null,
                  child: const Text('Continue'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when no issue has proposals yet: the resident can still write their own.
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
  const _IssueList({
    required this.catalogue,
    required this.draft,
    required this.enabled,
    required this.onToggleIssue,
    required this.onToggleProposal,
  });

  final TopicCatalogue catalogue;
  final Draft draft;
  final bool enabled;
  final void Function(TopicSummary issue, bool selected, TopicCatalogue catalogue) onToggleIssue;
  final void Function(TopicSummary issue, ProposalSummary proposal, bool selected, TopicCatalogue catalogue)
  onToggleProposal;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final issue in catalogue.topics) ...[
            CheckboxListTile(
              title: Text(issue.title),
              value: draft.issues.any((chosen) => chosen.id == issue.id),
              onChanged: enabled ? (checked) => onToggleIssue(issue, checked ?? false, catalogue) : null,
            ),
            if (draft.issues.any((chosen) => chosen.id == issue.id))
              for (final proposal in issue.proposals)
                Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(proposal.text),
                    value: (draft.ticked[issue.id] ?? const []).contains(proposal.id),
                    onChanged: enabled
                        ? (checked) => onToggleProposal(issue, proposal, checked ?? false, catalogue)
                        : null,
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
