import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/draft/draft_notifier.dart';
import '../providers/reference_data/reference_data_providers.dart';
import '../widgets/error_banner.dart';
import '../widgets/loading_view.dart';
import '../widgets/step_progress_indicator.dart';

/// Step 1 of the flow: GET /councils, unauthenticated.
class CouncilPickerScreen extends ConsumerWidget {
  const CouncilPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final councilsAsync = ref.watch(councilsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Select your council')),
      body: Column(
        children: [
          const StepProgressIndicator(currentStep: 1, totalSteps: 5, label: 'Council'),
          Expanded(
            child: councilsAsync.when(
              loading: () => const LoadingView(),
              error: (error, _) => ErrorBanner(
                message: 'Could not load councils. Please check your connection and try again.',
                onRetry: () => ref.invalidate(councilsProvider),
              ),
              data: (councils) => ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: councils.length,
                itemBuilder: (context, index) {
                  final council = councils[index];
                  return Card(
                    child: ListTile(
                      title: Text(council.name),
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
