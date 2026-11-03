import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/council.dart';
import '../providers/draft/draft_notifier.dart';
import '../providers/reference_data/reference_data_providers.dart';
import '../utils/counts.dart';
import '../widgets/app_banner.dart';
import '../widgets/error_banner.dart';
import '../widgets/loading_view.dart';
import '../widgets/step_progress_indicator.dart';

/// Step 1 of the flow: GET /councils, unauthenticated.
///
/// There are 31 councils, more than fit on a screen, so the list has a
/// scrollbar that is always showing (a plain scrolling list gave no sign that
/// there was more below the fold) and a search box.
class CouncilPickerScreen extends ConsumerStatefulWidget {
  const CouncilPickerScreen({super.key});

  @override
  ConsumerState<CouncilPickerScreen> createState() => _CouncilPickerScreenState();
}

class _CouncilPickerScreenState extends ConsumerState<CouncilPickerScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Lower case, with the fadas removed, so "dun" finds "Dún Laoghaire".
  static String _fold(String text) {
    const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u'};
    final lower = text.toLowerCase();
    return [for (final rune in lower.runes) accents[String.fromCharCode(rune)] ?? String.fromCharCode(rune)].join();
  }

  /// The councils whose names contain every word typed, in any order.
  List<Council> _matching(List<Council> councils) {
    final words = _fold(_query).split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
    if (words.isEmpty) return councils;
    return [
      for (final council in councils)
        if (words.every(_fold(council.name).contains)) council,
    ];
  }

  void _setQuery(String value) => setState(() => _query = value);

  void _clearSearch() {
    _searchController.clear();
    _setQuery('');
  }

  @override
  Widget build(BuildContext context) {
    final councilsAsync = ref.watch(councilsProvider);

    return Scaffold(
      appBar: AppBar(title: const AppBanner()),
      body: Column(
        children: [
          const StepProgressIndicator(currentStep: 1, totalSteps: 5, label: 'Select your council'),
          Expanded(
            child: councilsAsync.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorBanner(
                message: 'Could not load councils. Please check your connection and try again.',
                onRetry: () => ref.invalidate(councilsProvider),
              ),
              data: (councils) {
                final shown = _matching(councils);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Search councils',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _query.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  tooltip: 'Clear search',
                                  onPressed: _clearSearch,
                                ),
                        ),
                        textInputAction: TextInputAction.search,
                        onChanged: _setQuery,
                      ),
                    ),
                    if (shown.any((council) => council.councillorCount > 0))
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${countOf(shown.length, 'council')} · '
                            '${countOf(shown.fold<int>(0, (sum, council) => sum + council.councillorCount), 'councillor')}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: shown.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'No council matches "${_query.trim()}". Check the spelling, or clear the search.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : Scrollbar(
                              controller: _scrollController,
                              thumbVisibility: true,
                              child: ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                itemCount: shown.length,
                                itemBuilder: (context, index) {
                                  final council = shown[index];
                                  return Card(
                                    child: ListTile(
                                      title: Text(council.name),
                                      subtitle: council.councillorCount > 0
                                          ? Text(
                                              '${countOf(council.areaCount, 'area')} · '
                                              '${countOf(council.councillorCount, 'councillor')}',
                                            )
                                          : null,
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () {
                                        ref.read(draftNotifierProvider.notifier).selectCouncil(council);
                                        context.push('/council/${council.id}/lea');
                                      },
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
          // Debug-only side door for exercising a real send end-to-end
          // through the UI without a real councillor — see
          // DraftNotifier.selectTestRecipient's doc comment. Never
          // appears in a release build.
          if (kDebugMode)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextButton(
                  onPressed: () {
                    ref.read(draftNotifierProvider.notifier).selectTestRecipient();
                    context.push('/compose');
                  },
                  child: const Text('Use test recipient (dev)'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
