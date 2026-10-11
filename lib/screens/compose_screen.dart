import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/draft.dart';
import '../models/topic_catalogue.dart';
import '../models/topic_summary.dart';
import '../providers/draft/draft_notifier.dart';
import '../providers/reference_data/reference_data_providers.dart';
import '../widgets/app_banner.dart';
import '../widgets/error_banner.dart';
import '../widgets/loading_view.dart';
import '../widgets/step_progress_indicator.dart';

/// Step 3: either pick one or more topics (the server writes a first draft
/// the resident can edit) or write the email from scratch, then add a name
/// for the sign-off. Only asking the server for topic text happens here —
/// nothing is stored until the message is drafted after the email sign-in
/// (the router's redirect guard already ensures an LEA is selected before
/// this screen is reachable).
class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({super.key});

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _subjectController;
  late final TextEditingController _bodyController;

  /// True while topic text is being fetched.
  bool _composing = false;
  String? _composeError;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(draftNotifierProvider);
    _nameController = TextEditingController(text: draft.senderName);
    _subjectController = TextEditingController(text: draft.subject);
    _bodyController = TextEditingController(text: draft.body);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

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

  Future<void> _changeMode(ComposeMode mode) async {
    final draft = ref.read(draftNotifierProvider);
    if (mode == draft.mode) return;
    if (draft.hasEditedText && !await _confirmDiscard('This clears what you have written. Continue?')) return;
    if (!mounted) return;
    setState(() {
      _composing = false;
      _composeError = null;
    });
    ref.read(draftNotifierProvider.notifier).setMode(mode);
  }

  Future<void> _toggleTopic(TopicSummary topic, bool selected, TopicCatalogue catalogue) async {
    final draft = ref.read(draftNotifierProvider);
    final ids = {for (final chosen in draft.topics) chosen.id};
    selected ? ids.add(topic.id) : ids.remove(topic.id);
    // The catalogue's order, whatever order the boxes were ticked in.
    final next = [
      for (final candidate in catalogue.topics)
        if (ids.contains(candidate.id)) candidate,
    ];

    if (draft.hasEditedText && !await _confirmDiscard('This replaces your edits. Continue?')) return;
    if (!mounted) return;

    setState(() {
      _composing = true;
      _composeError = null;
    });
    final error = await ref.read(draftNotifierProvider.notifier).chooseTopics(next);
    if (!mounted) return;
    setState(() {
      _composing = false;
      _composeError = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalogueAsync = ref.watch(topicCatalogueProvider);
    final draft = ref.watch(draftNotifierProvider);
    final notifier = ref.read(draftNotifierProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // The text was replaced from outside the text fields (topics composed, or
    // the mode changed): show it in them.
    ref.listen<int>(draftNotifierProvider.select((current) => current.revision), (_, _) {
      final current = ref.read(draftNotifierProvider);
      _subjectController.text = current.subject;
      _bodyController.text = current.body;
    });

    final showTextFields = draft.mode == ComposeMode.ownWords || draft.topics.isNotEmpty;
    final layout = catalogueAsync.value?.emailLayout;

    return Scaffold(
      appBar: AppBar(title: const AppBanner()),
      body: Column(
        children: [
          StepProgressIndicator(
            currentStep: 3,
            totalSteps: 5,
            label: 'Write your message — ${draft.lea?.name ?? ''}',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                SegmentedButton<ComposeMode>(
                  segments: const [
                    ButtonSegment(value: ComposeMode.topics, label: Text('Select a topic')),
                    ButtonSegment(value: ComposeMode.ownWords, label: Text('Write your own')),
                  ],
                  selected: {draft.mode},
                  onSelectionChanged: _composing ? null : (selection) => _changeMode(selection.first),
                ),
                const SizedBox(height: 16),
                if (draft.mode == ComposeMode.topics) ...[
                  Text(
                    'Choose one or more topics. We write a first draft that you can change.',
                    style: textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  catalogueAsync.when(
                    loading: () => const LoadingView(),
                    error: (error, _) => ErrorBanner(
                      message: 'Could not load topics. Please check your connection and try again.',
                      onRetry: () => ref.invalidate(topicCatalogueProvider),
                    ),
                    data: (catalogue) => Card(
                      child: Column(
                        children: [
                          for (final topic in catalogue.topics)
                            CheckboxListTile(
                              title: Text(topic.title),
                              value: draft.topics.any((chosen) => chosen.id == topic.id),
                              onChanged: _composing
                                  ? null
                                  : (checked) => _toggleTopic(topic, checked ?? false, catalogue),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (_composing) ...[const SizedBox(height: 8), const LinearProgressIndicator()],
                  if (_composeError != null) ...[const SizedBox(height: 8), ErrorBanner(message: _composeError!)],
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Your name', helperText: 'Signs off your email.'),
                  maxLength: maxSenderNameLength,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  onChanged: notifier.setSenderName,
                ),
                if (showTextFields) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _subjectController,
                    decoration: const InputDecoration(labelText: 'Subject'),
                    onChanged: notifier.setSubject,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _bodyController,
                    decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true),
                    minLines: 10,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    onChanged: notifier.setBody,
                  ),
                  if (draft.hasUnfinishedText) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Your message still has text in double square brackets, like [[this]]. '
                      'Replace it with your own words before you continue.',
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    layout == null
                        ? 'We add a greeting for each councillor, and your name, around your message.'
                        : 'We add "${layout.greetingFormat.replaceAll('{name}', '<name>')}" at the start, with each '
                              'councillor\'s own name, and "${layout.signOff}" and your name at the end.',
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                  if (draft.footer != null)
                    Text(
                      'Added under your name, and not editable: "${draft.footer}"',
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                ] else if (draft.mode == ComposeMode.topics) ...[
                  const SizedBox(height: 16),
                  Text('Pick a topic to see the draft.', style: textTheme.bodySmall),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: draft.isReadyToReview && !_composing ? () => context.push('/review') : null,
                  child: const Text('Continue'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
