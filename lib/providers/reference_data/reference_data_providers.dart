import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/council.dart';
import '../../models/lea.dart';
import '../../models/topic_catalogue.dart';
import '../core_providers.dart';

/// The topics to pick from and the fixed parts of every email (greeting and
/// sign-off), loaded once from GET /topics.
final topicCatalogueProvider = FutureProvider<TopicCatalogue>((ref) {
  return ref.watch(apiClientProvider).getTopics();
});

final councilsProvider = FutureProvider<List<Council>>((ref) {
  return ref.watch(apiClientProvider).getCouncils();
});

final leasForCouncilProvider = FutureProvider.family<List<Lea>, String>((ref, councilId) {
  return ref.watch(apiClientProvider).getLeasForCouncil(councilId);
});
