import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/council.dart';
import '../../models/councillor_preview.dart';
import '../../models/draft.dart';
import '../../models/lea.dart';

/// The backend's manual-test-recipient fixture (see
/// scripts/seed_manual_test_lea.py in the CBA repo) — resolvable by
/// POST /messages but deliberately excluded from every public listing
/// (GET /leas, GET /councils/{id}/leas), so it can never be reached
/// through the normal picker. selectTestRecipient() is the app's own
/// debug-only side door for exercising a real send end-to-end through
/// the UI without touching real councillors.
const _testRecipientLea = Lea(
  id: 'manual-test-recipient',
  name: 'Manual Test Recipient (dev)',
  council: 'Test Fixture',
  councillors: [
    CouncillorPreview(name: 'Test inboxes — see seed_manual_test_lea.py', party: '—'),
  ],
);

class DraftNotifier extends StateNotifier<Draft> {
  DraftNotifier() : super(const Draft());

  void selectCouncil(Council council) {
    // A new council invalidates any LEA picked under the previous one.
    state = state.copyWith(council: council, clearLea: true);
  }

  void selectLea(Lea lea) {
    state = state.copyWith(lea: lea);
  }

  /// Debug-only: see _testRecipientLea's doc comment.
  void selectTestRecipient() {
    state = state.copyWith(lea: _testRecipientLea);
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
