import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exceptions.dart';
import '../../models/council.dart';
import '../../models/councillor_preview.dart';
import '../../models/draft.dart';
import '../../models/lea.dart';
import '../../models/topic_summary.dart';
import '../core_providers.dart';

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

class DraftNotifier extends Notifier<Draft> {
  /// Numbers each request for topic text, so a slow answer to an earlier
  /// tick can never overwrite the answer to a later one.
  int _latestComposeRequest = 0;

  @override
  Draft build() => const Draft();

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

  /// Switches between starting from topics and writing everything yourself.
  /// The text belongs to the old mode, so it is cleared (the screen asks
  /// first when the resident has edited it).
  void setMode(ComposeMode mode) {
    if (mode == state.mode) return;
    _latestComposeRequest++; // an answer still on its way is for the old mode
    state = _withoutText(state).copyWith(mode: mode);
  }

  /// Fills the subject, body and footer from the server for exactly the
  /// topics in [chosen] (replacing whatever text there was). Topics already
  /// composed this session keep their variant; the others get a random one.
  /// Returns null on success, or a message to show the resident.
  Future<String?> chooseTopics(List<TopicSummary> chosen) async {
    final request = ++_latestComposeRequest;
    if (chosen.isEmpty) {
      state = _withoutText(state);
      return null;
    }
    final lea = state.lea;
    if (lea == null) return 'Choose your area first.';

    try {
      final composed = await ref
          .read(apiClientProvider)
          .composeTopics(
            localElectoralArea: lea.id,
            topics: [for (final topic in chosen) topic.id],
            variants: state.templateVariants,
          );
      if (request != _latestComposeRequest) return null; // superseded by a later choice

      final byId = {for (final topic in chosen) topic.id: topic};
      state = state.copyWith(
        topics: [for (final id in composed.topics) byId[id]!],
        // Remember every variant, so un-ticking and re-ticking a topic does not re-roll it.
        templateVariants: {...state.templateVariants, ...composed.variants},
        footer: composed.footer,
        subject: composed.subject,
        body: composed.body,
        composedSubject: composed.subject,
        composedBody: composed.body,
        revision: state.revision + 1,
      );
      return null;
    } on NetworkException {
      if (request != _latestComposeRequest) return null;
      return 'Could not load the text for these topics. Please check your connection and try again.';
    } on ApiException catch (e) {
      if (request != _latestComposeRequest) return null;
      return e.message;
    }
  }

  void setSenderName(String name) {
    state = state.copyWith(senderName: name);
  }

  void setSubject(String subject) {
    state = state.copyWith(subject: subject);
  }

  void setBody(String body) {
    state = state.copyWith(body: body);
  }

  /// No topics, no text, no footer: the compose form as it is before anything is chosen.
  Draft _withoutText(Draft draft) {
    return draft.copyWith(
      topics: const [],
      clearFooter: true,
      subject: '',
      body: '',
      composedSubject: '',
      composedBody: '',
      revision: draft.revision + 1,
    );
  }

  /// Every "start over" path ends here (the banner's Start over, Result's
  /// Back to start, Reconnect's Start again), so this also wipes the saved
  /// copy — otherwise a draft abandoned mid-connect would stay in the
  /// browser's storage indefinitely (GDPR review, finding 9).
  void clear() {
    _latestComposeRequest++;
    state = const Draft();
    // Read here, only when a draft is actually cleared — storage is set up
    // in main() and needn't exist just to build the notifier.
    unawaited(ref.read(draftStorageServiceProvider).clear());
  }
}

final draftNotifierProvider = NotifierProvider<DraftNotifier, Draft>(DraftNotifier.new);
