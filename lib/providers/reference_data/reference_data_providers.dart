import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/campaign_summary.dart';
import '../../models/council.dart';
import '../../models/lea.dart';
import '../../models/place_match.dart';
import '../../models/topic_catalogue.dart';
import '../core_providers.dart';

/// The issues to pick from (each with its proposals) and the fixed parts of
/// every email (greeting and sign-off), loaded once from GET /topics.
final topicCatalogueProvider = FutureProvider<TopicCatalogue>((ref) {
  return ref.watch(apiClientProvider).getTopics();
});

/// The campaigns a resident can back, loaded once from GET /campaigns.
final campaignsProvider = FutureProvider<List<CampaignSummary>>((ref) {
  return ref.watch(apiClientProvider).getCampaigns();
});

final councilsProvider = FutureProvider<List<Council>>((ref) {
  return ref.watch(apiClientProvider).getCouncils();
});

final leasForCouncilProvider = FutureProvider.family<List<Lea>, String>((ref, councilId) {
  return ref.watch(apiClientProvider).getLeasForCouncil(councilId);
});

/// The areas a typed place name is in. Keyed by the text, and dropped when the
/// screen stops watching it, so searches are not kept.
final placeSearchProvider = FutureProvider.autoDispose.family<PlaceSearchResults, String>((ref, query) {
  return ref.watch(apiClientProvider).searchPlaces(query);
});
