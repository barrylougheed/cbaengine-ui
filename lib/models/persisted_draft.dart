import 'package:equatable/equatable.dart';

import 'draft.dart';
import 'topic_summary.dart';

/// The persisted shape in shared_preferences (DraftStorageService) — IDs
/// and names only, never the full Lea (with its councillor list):
/// restoring a draft re-fetches GET /councils/{id}/leas rather than
/// trusting a possibly-stale cached councillor list.
///
/// Written once, just before the email sign-in (which can reload the whole
/// app on the web), and read once, after it. Version 2 added the topics, the
/// variants and the resident's name; a draft saved by version 1 is ignored.
class PersistedDraft extends Equatable {
  const PersistedDraft({
    this.councilId,
    this.councilName,
    this.leaId,
    this.leaName,
    this.mode = ComposeMode.topics,
    this.topicIds = const [],
    this.templateVariants = const {},
    this.senderName = '',
    this.subject = '',
    this.body = '',
    required this.savedAt,
  });

  static const version = 2;

  final String? councilId;
  final String? councilName;
  final String? leaId;
  final String? leaName;
  final ComposeMode mode;
  final List<String> topicIds;
  final Map<String, String> templateVariants;
  final String senderName;
  final String subject;
  final String body;
  final DateTime savedAt;

  /// The topic ids to send to the API: "custom" for the resident's own words.
  List<String> get apiTopics => mode == ComposeMode.ownWords ? const [customTopicId] : topicIds;

  factory PersistedDraft.fromJson(Map<String, dynamic> json) {
    if (json['version'] != version) throw const FormatException('Unsupported saved draft version.');
    return PersistedDraft(
      councilId: json['councilId'] as String?,
      councilName: json['councilName'] as String?,
      leaId: json['leaId'] as String?,
      leaName: json['leaName'] as String?,
      mode: ComposeMode.values.byName(json['mode'] as String? ?? ComposeMode.topics.name),
      topicIds: List<String>.from(json['topicIds'] as List<dynamic>? ?? const []),
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
      'mode': mode.name,
      'topicIds': topicIds,
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
    mode,
    topicIds,
    templateVariants,
    senderName,
    subject,
    body,
    savedAt,
  ];
}
