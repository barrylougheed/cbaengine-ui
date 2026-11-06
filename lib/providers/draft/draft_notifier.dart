import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exceptions.dart';
import '../../models/campaign_summary.dart';
import '../../models/council.dart';
import '../../models/councillor_preview.dart';
import '../../models/draft.dart';
import '../../models/lea.dart';
import '../../models/message_intent.dart';
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
  /// Numbers each request for text, so a slow answer to an earlier choice can
  /// never overwrite the answer to a later one (or to a change of the kind of email).
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

  /// Switches between an email about issues, one the resident writes, and one
  /// backing a campaign. What was chosen and written belongs to the old kind,
  /// so it is cleared (the screen asks first when the resident has edited the
  /// text). The name, council and area stay.
  void setIntent(MessageIntent intent) {
    if (intent == state.intent) return;
    _latestComposeRequest++; // an answer still on its way is for the old kind
    state = _withoutContent(state).copyWith(intent: intent);
  }

  /// Sets the chosen [chosen] issues and the proposals [ticked] for each
  /// (issue id -> proposal ids). Once every chosen issue has a proposal ticked,
  /// fills the subject, body and footer from the server (replacing whatever
  /// text there was); until then there is no text. Wording already shown for an
  /// issue is kept, so ticking and un-ticking never re-rolls it.
  /// Returns null on success, or a message to show the resident.
  Future<String?> chooseIssues(List<TopicSummary> chosen, Map<String, List<String>> ticked) async {
    final request = ++_latestComposeRequest;
    final cleanTicked = {for (final issue in chosen) issue.id: ticked[issue.id] ?? const <String>[]};
    final complete = chosen.isNotEmpty && chosen.every((issue) => cleanTicked[issue.id]!.isNotEmpty);
    if (!complete) {
      state = _withoutText(state).copyWith(issues: chosen, ticked: cleanTicked);
      return null;
    }

    try {
      final composed = await ref
          .read(apiClientProvider)
          .composeTopics(selection: cleanTicked, variants: state.templateVariants);
      if (request != _latestComposeRequest) return null; // superseded by a later choice

      final byId = {for (final issue in chosen) issue.id: issue};
      state = state.copyWith(
        issues: [for (final id in composed.topics) byId[id]!],
        ticked: cleanTicked,
        // Remember all the wording, so un-ticking and re-ticking an issue does not re-roll it.
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
      return 'Could not load the text for these issues. Please check your connection and try again.';
    } on ApiException catch (e) {
      if (request != _latestComposeRequest) return null;
      return e.message;
    }
  }

  /// Chooses [campaign] and fills the subject, body and footer from the server
  /// (replacing whatever text there was). A variant already shown for it is
  /// kept. Returns null on success, or a message to show the resident.
  Future<String?> chooseCampaign(CampaignSummary campaign) async {
    final request = ++_latestComposeRequest;
    try {
      final composed = await ref
          .read(apiClientProvider)
          .composeCampaign(campaignId: campaign.id, variants: state.templateVariants);
      if (request != _latestComposeRequest) return null;

      state = state.copyWith(
        campaign: campaign,
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
      return 'Could not load the text for this campaign. Please check your connection and try again.';
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

  /// No text and no footer: what the form shows before there is anything to write.
  Draft _withoutText(Draft draft) {
    return draft.copyWith(
      clearFooter: true,
      subject: '',
      body: '',
      composedSubject: '',
      composedBody: '',
      revision: draft.revision + 1,
    );
  }

  /// Nothing chosen and no text: the start of any kind of email.
  Draft _withoutContent(Draft draft) {
    return _withoutText(draft).copyWith(
      issues: const [],
      ticked: const {},
      clearCampaign: true,
      templateVariants: const {},
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
