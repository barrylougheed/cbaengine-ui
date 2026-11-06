import 'package:equatable/equatable.dart';

import 'message_intent.dart';
import 'topic_summary.dart';

/// The persisted shape in shared_preferences (DraftStorageService) — IDs
/// and names only, never the full Lea (with its councillor list):
/// restoring a draft re-fetches GET /councils/{id}/leas rather than
/// trusting a possibly-stale cached councillor list.
///
/// Written once, just before the email sign-in (which can reload the whole
/// app on the web), and read once, after it, then deleted. It lives only in the
/// resident's own browser. Version 3 added the kind of email and the ticked
/// proposals; a draft saved by an earlier version is ignored.
class PersistedDraft extends Equatable {
  const PersistedDraft({
    this.councilId,
    this.councilName,
    this.leaId,
    this.leaName,
    this.intent = MessageIntent.issues,
    this.topicIds = const [],
    this.proposals = const {},
    this.templateVariants = const {},
    this.senderName = '',
    this.subject = '',
    this.body = '',
    required this.savedAt,
  });

  static const version = 3;

  final String? councilId;
  final String? councilName;
  final String? leaId;
  final String? leaName;
  final MessageIntent intent;

  /// The chosen issue ids, or the campaign's id (empty for the resident's own words).
  final List<String> topicIds;

  /// Issue id -> ids of the proposals ticked for it.
  final Map<String, List<String>> proposals;

  /// The wording shown: issue id -> opener id and "_subject" -> subject id, or
  /// campaign id -> variant id.
  final Map<String, String> templateVariants;
  final String senderName;
  final String subject;
  final String body;
  final DateTime savedAt;

  /// The topic ids to send to the API: "custom" for the resident's own words.
  List<String> get apiTopics => intent == MessageIntent.own ? const [customTopicId] : topicIds;

  factory PersistedDraft.fromJson(Map<String, dynamic> json) {
    if (json['version'] != version) throw const FormatException('Unsupported saved draft version.');
    return PersistedDraft(
      councilId: json['councilId'] as String?,
      councilName: json['councilName'] as String?,
      leaId: json['leaId'] as String?,
      leaName: json['leaName'] as String?,
      intent: MessageIntent.values.byName(json['intent'] as String? ?? MessageIntent.issues.name),
      topicIds: List<String>.from(json['topicIds'] as List<dynamic>? ?? const []),
      proposals: {
        for (final entry in (json['proposals'] as Map<String, dynamic>? ?? const {}).entries)
          entry.key: List<String>.from(entry.value as List<dynamic>),
      },
      templateVariants: Map<String, String>.from(json['templateVariants'] as Map<String, dynamic>? ?? const {}),
      senderName: json['senderName'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      body: json['body'] as String? ?? '',
      savedAt: DateTime.parse(json['savedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'councilId': councilId,
      'councilName': councilName,
      'leaId': leaId,
      'leaName': leaName,
      'intent': intent.name,
      'topicIds': topicIds,
      'proposals': proposals,
      'templateVariants': templateVariants,
      'senderName': senderName,
      'subject': subject,
      'body': body,
      'savedAt': savedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    councilId,
    councilName,
    leaId,
    leaName,
    intent,
    topicIds,
    proposals,
    templateVariants,
    senderName,
    subject,
    body,
    savedAt,
  ];
}
