import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/topic_catalogue.dart';
import '../models/topic_summary.dart';
import '../providers/draft/draft_notifier.dart';
import '../providers/reference_data/reference_data_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/confirm_discard.dart';
import '../widgets/error_banner.dart';
import '../widgets/loading_view.dart';
import '../widgets/step_page.dart';

/// The second screen of an email about issues: choose one or more topics in a
/// category. Ticking only records the choice (the text is written once a letter
/// style is chosen), so it costs no request. The choice is kept when going back
/// to add a topic from another category; Continue goes on to the style.
///
/// Changing the topics takes away text already written for the old choice, so
/// the resident is asked first when they have edited that text.
class TopicsScreen extends ConsumerWidget {
  const TopicsScreen({super.key, required this.categoryId});

  final String categoryId;

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    TopicSummary topic,
    bool selected,
    TopicCatalogue catalogue,
  ) async {
    if (ref.read(draftNotifierProvider).hasEditedText &&
        !await confirmDiscard(context, 'This replaces your edits. Continue?')) {
      return;
    }
    // Read again: the choice may have changed while the question was open.
    final chosenIds = {for (final chosen in ref.read(draftNotifierProvider).issues) chosen.id};
    selected ? chosenIds.add(topic.id) : chosenIds.remove(topic.id);
    // In the list's order, whatever order they were ticked in and whichever
    // category they are in.
    ref.read(draftNotifierProvider.notifier).setIssues([
      for (final candidate in catalogue.topics)
        if (chosenIds.contains(candidate.id)) candidate,
    ]);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogueAsync = ref.watch(topicCatalogueProvider);
    final draft = ref.watch(draftNotifierProvider);
    final textTheme = Theme.of(context).textTheme;

    final category = catalogueAsync.value?.categories.where((candidate) => candidate.id == categoryId).firstOrNull;

    return StepPage(
      step: 1,
      label: 'Choose a topic',
      action: FilledButton(
        onPressed: draft.issues.isEmpty ? null : () => context.push('/craft/issues/style'),
        child: const Text('Continue'),
      ),
      children: [
        catalogueAsync.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorBanner(
            message: 'Could not load the issues. Please check your connection and try again.',
            onRetry: () => ref.invalidate(topicCatalogueProvider),
          ),
          data: (catalogue) {
            if (category == null) return _UnknownCategory(onChoose: () => context.go('/craft/issues'));
            final topics = catalogue.topicsIn(category.id);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(category.title, style: textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Choose one or more topics. You can add topics from other categories too.',
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
                ),
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final (index, topic) in topics.indexed) ...[
                        if (index > 0) const Divider(height: 1),
                        CheckboxListTile(
                          title: Text(topic.title),
                          value: draft.issues.any((chosen) => chosen.id == topic.id),
                          onChanged: (checked) => _toggle(context, ref, topic, checked ?? false, catalogue),
                        ),
                      ],
                    ],
                  ),
                ),
                if (draft.issues.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'You have chosen: ${draft.issues.map((issue) => issue.title).join(', ')}',
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    // Pushed, not popped: this screen may have been opened directly.
                    onPressed: () => context.push('/craft/issues'),
                    child: const Text('Choose from another category'),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

/// A link to a category that does not exist (an old or mistyped address).
class _UnknownCategory extends StatelessWidget {
  const _UnknownCategory({required this.onChoose});

  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('We could not find that category.'),
        const SizedBox(height: 12),
        FilledButton(onPressed: onChoose, child: const Text('Choose a category')),
      ],
    );
  }
}
