import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/council.dart';
import '../../models/draft.dart';
import '../../models/lea.dart';

class DraftNotifier extends StateNotifier<Draft> {
  DraftNotifier() : super(const Draft());

  void selectCouncil(Council council) {
    // A new council invalidates any LEA picked under the previous one.
    state = state.copyWith(council: council, clearLea: true);
  }

  void selectLea(Lea lea) {
    state = state.copyWith(lea: lea);
  }

  void setTopic(String topic) {
    state = state.copyWith(topic: topic);
  }

  void setSubject(String subject) {
    state = state.copyWith(subject: subject);
  }

  void setBody(String body) {
    state = state.copyWith(body: body);
  }

  void clear() {
    state = const Draft();
  }
}

final draftNotifierProvider = StateNotifierProvider<DraftNotifier, Draft>((ref) => DraftNotifier());
