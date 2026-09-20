import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/council.dart';
import '../../models/lea.dart';
import '../core_providers.dart';

final topicsProvider = FutureProvider<List<String>>((ref) {
  return ref.watch(apiClientProvider).getTopics();
});

final councilsProvider = FutureProvider<List<Council>>((ref) {
  return ref.watch(apiClientProvider).getCouncils();
});

final leasForCouncilProvider = FutureProvider.family<List<Lea>, String>((ref, councilId) {
  return ref.watch(apiClientProvider).getLeasForCouncil(councilId);
});
