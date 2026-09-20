import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/draft/draft_notifier.dart';
import '../providers/reference_data/reference_data_providers.dart';
import '../widgets/error_banner.dart';
import '../widgets/loading_view.dart';

/// Step 1 of the flow: GET /councils, unauthenticated.
class CouncilPickerScreen extends ConsumerWidget {
  const CouncilPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final councilsAsync = ref.watch(councilsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Select your council')),
      body: councilsAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorBanner(
          message: 'Could not load councils. Please check your connection and try again.',
          onRetry: () => ref.invalidate(councilsProvider),
        ),
        data: (councils) => ListView.builder(
          itemCount: councils.length,
          itemBuilder: (context, index) {
            final council = councils[index];
            return ListTile(
              title: Text(council.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ref.read(draftNotifierProvider.notifier).selectCouncil(council);
                context.go('/council/${council.id}/lea');
              },
            );
          },
        ),
      ),
    );
  }
}
