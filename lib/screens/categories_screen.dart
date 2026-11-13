import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/category_summary.dart';
import '../models/message_intent.dart';
import '../models/topic_catalogue.dart';
import '../providers/draft/draft_notifier.dart';
import '../providers/reference_data/reference_data_providers.dart';
import '../theme/app_theme.dart';
import '../utils/counts.dart';
import '../widgets/choice_card.dart';
import '../widgets/confirm_discard.dart';
import '../widgets/error_banner.dart';
import '../widgets/loading_view.dart';
import '../widgets/step_page.dart';

/// The first screen of an email about issues: choose a category (Housing,
/// Healthcare...). The server sends only the categories that have an issue
/// ready, in the owner's order. Choosing one opens the topics in it; once some
/// topics are chosen, Continue goes on to the choice of letter style. Nothing
/// here needs an area, and nothing is asked of the server beyond the list.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _writeMyOwn(BuildContext context, WidgetRef ref) async {
    final draft = ref.read(draftNotifierProvider);
    if (draft.hasEditedText && !await confirmDiscard(context, 'This clears what you have written. Continue?')) return;
    if (!context.mounted) return;
    ref.read(draftNotifierProvider.notifier).setIntent(MessageIntent.own);
    context.pushReplacement('/craft/own');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogueAsync = ref.watch(topicCatalogueProvider);
    final draft = ref.watch(draftNotifierProvider);
    final textTheme = Theme.of(context).textTheme;
    final hasCategories = catalogueAsync.value?.categories.isNotEmpty ?? false;

    return StepPage(
      step: 1,
      label: 'Choose a category',
      // Only once something has been chosen: otherwise there is nothing to go on with.
      action: draft.issues.isEmpty
          ? null
          : FilledButton(onPressed: () => context.push('/craft/issues/style'), child: const Text('Continue')),
      children: [
        Text('Choose a category', style: textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Pick the area your concern is in. You will choose the specific topics next.',
          style: textTheme.bodyMedium?.copyWith(color: AppColors.mutedText),
        ),
        const SizedBox(height: 16),
        catalogueAsync.when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorBanner(
            message: 'Could not load the issues. Please check your connection and try again.',
            onRetry: () => ref.invalidate(topicCatalogueProvider),
          ),
          data: (catalogue) => catalogue.categories.isEmpty
              ? _NoIssuesYet(onWriteMyOwn: () => _writeMyOwn(context, ref))
              : _CategoryGrid(catalogue: catalogue),
        ),
        if (draft.issues.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'You have chosen: ${draft.issues.map((issue) => issue.title).join(', ')}',
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
        if (hasCategories) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => _writeMyOwn(context, ref),
              child: const Text('Want to say something different? Write your own email.'),
            ),
          ),
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

/// The categories as a grid of tiles: three across where there is room, two on
/// a phone, reading across and then down in the server's order. Each row is as
/// tall as its tallest tile (a long title wraps), and a short last row keeps the
/// same tile width as the rows above it instead of stretching its tiles.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.catalogue});

  final TopicCatalogue catalogue;

  static const double _gap = 12;

  /// The column width from which the tiles go three across rather than two.
  static const double _threeAcrossFrom = 560;

  /// An icon for a category the owner has named; anything new gets a plain tag
  /// until it is given one here.
  static IconData _iconFor(CategorySummary category) => switch (category.id) {
    'housing' => Icons.home_outlined,
    'homelessness' => Icons.night_shelter_outlined,
    'healthcare' => Icons.local_hospital_outlined,
    'cost-of-living' => Icons.shopping_cart_outlined,
    'environmentalism' => Icons.eco_outlined,
    'education' => Icons.school_outlined,
    'community-issues' => Icons.groups_outlined,
    'employment' => Icons.work_outline,
    'geopolitics' => Icons.public,
    _ => Icons.label_outline,
  };

  Widget _tile(BuildContext context, CategorySummary category) {
    return ChoiceCard(
      compact: true,
      icon: _iconFor(category),
      title: category.title,
      subtitle: countOf(catalogue.topicsIn(category.id).length, 'topic'),
      onTap: () => context.push('/craft/issues/category/${category.id}'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = catalogue.categories;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= _threeAcrossFrom ? 3 : 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var start = 0; start < categories.length; start += columns) ...[
              if (start > 0) const SizedBox(height: _gap),
              // IntrinsicHeight makes the tiles in a row equally tall.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var column = 0; column < columns; column++) ...[
                      if (column > 0) const SizedBox(width: _gap),
                      // An empty cell where a short last row has no tile, so the
                      // tiles that are there keep the width they have above.
                      Expanded(
                        child: start + column < categories.length
                            ? _tile(context, categories[start + column])
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
