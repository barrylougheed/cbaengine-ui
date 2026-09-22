import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/draft/draft_notifier.dart';
import '../providers/reference_data/reference_data_providers.dart';
import '../widgets/error_banner.dart';
import '../widgets/home_action.dart';
import '../widgets/loading_view.dart';
import '../widgets/step_progress_indicator.dart';

/// Step 3: topic/subject/body, one screen. Purely local draft state —
/// no backend call happens here (the router's redirect guard already
/// ensures an LEA is selected before this screen is reachable).
class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({super.key});

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  late final TextEditingController _subjectController;
  late final TextEditingController _bodyController;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(draftNotifierProvider);
    _subjectController = TextEditingController(text: draft.subject);
    _bodyController = TextEditingController(text: draft.body);
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topicsAsync = ref.watch(topicsProvider);
    final draft = ref.watch(draftNotifierProvider);
    final notifier = ref.read(draftNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text('Write your message — ${draft.lea?.name ?? ''}'),
        actions: const [HomeAction()],
      ),
      body: Column(
        children: [
          const StepProgressIndicator(currentStep: 3, totalSteps: 5, label: 'Compose'),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  topicsAsync.when(
                    loading: () => const LoadingView(),
                    error: (error, _) => ErrorBanner(
                      message: 'Could not load topics. Please check your connection and try again.',
                      onRetry: () => ref.invalidate(topicsProvider),
                    ),
                    data: (topics) => DropdownButtonFormField<String>(
                      initialValue: draft.topic,
                      decoration: const InputDecoration(labelText: 'Topic'),
                      items: topics
                          .map((topic) => DropdownMenuItem(value: topic, child: Text(topic)))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) notifier.setTopic(value);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _subjectController,
                    decoration: const InputDecoration(labelText: 'Subject'),
                    onChanged: notifier.setSubject,
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: TextField(
                      controller: _bodyController,
                      decoration: const InputDecoration(labelText: 'Message', alignLabelWithHint: true),
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      onChanged: notifier.setBody,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: draft.isReadyToReview ? () => context.push('/review') : null,
                    child: const Text('Continue'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
