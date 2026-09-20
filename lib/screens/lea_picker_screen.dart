import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/draft/draft_notifier.dart';
import '../providers/reference_data/reference_data_providers.dart';
import '../widgets/error_banner.dart';
import '../widgets/loading_view.dart';

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
      appBar: AppBar(title: const Text('Select your area')),
      body: leasAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorBanner(
          message: 'Could not load areas for this council. Please check your connection and try again.',
          onRetry: () => ref.invalidate(leasForCouncilProvider(councilId)),
        ),
        data: (leas) => ListView.builder(
          itemCount: leas.length,
          itemBuilder: (context, index) {
            final lea = leas[index];
            return ListTile(
              title: Text(lea.name),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ref.read(draftNotifierProvider.notifier).selectLea(lea);
                context.go('/compose');
              },
            );
          },
        ),
      ),
    );
  }
}
