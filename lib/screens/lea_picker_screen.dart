import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../api/api_exceptions.dart';
import '../providers/draft/draft_notifier.dart';
import '../providers/reference_data/reference_data_providers.dart';
import '../widgets/error_banner.dart';
import '../widgets/home_action.dart';
import '../widgets/loading_view.dart';
import '../widgets/step_progress_indicator.dart';

/// Step 2: GET /councils/{councilId}/leas, unauthenticated. Reachable
/// directly by URL (the councilId path param alone is enough to fetch),
/// independent of whether draftNotifier already has a council selected
/// — but tapping an LEA here always writes into draftNotifier, since
/// Compose/Review read from there, not from the URL.
class LeaPickerScreen extends ConsumerWidget {
  const LeaPickerScreen({super.key, required this.councilId});

  final String councilId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leasAsync = ref.watch(leasForCouncilProvider(councilId));

    return Scaffold(
      appBar: AppBar(title: const Text('Select your area'), actions: const [HomeAction()]),
      body: Column(
        children: [
          const StepProgressIndicator(currentStep: 2, totalSteps: 5, label: 'Local Electoral Area'),
          Expanded(
            child: leasAsync.when(
              loading: () => const LoadingView(),
              error: (error, _) => error is NotFoundException
                  // Only reachable via a malformed deep link (a councilId
                  // that doesn't resolve to any council) — the backend's
                  // own wording ("Council not found.") is already correct
                  // and specific, so render it verbatim rather than the
                  // generic fallback below. No retry: a nonexistent
                  // council id won't start resolving.
                  ? ErrorBanner(message: error.message)
                  : ErrorBanner(
                      message:
                          'Could not load areas for this council. Please check your connection and try again.',
                      onRetry: () => ref.invalidate(leasForCouncilProvider(councilId)),
                    ),
              data: (leas) => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: leas.length,
                itemBuilder: (context, index) {
                  final lea = leas[index];
                  return Card(
                    child: ListTile(
                      title: Text(lea.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        ref.read(draftNotifierProvider.notifier).selectLea(lea);
                        context.push('/compose');
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
