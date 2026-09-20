import 'package:equatable/equatable.dart';

/// The persisted shape in shared_preferences (DraftStorageService) — IDs
/// and names only, never the full Lea (with its councillor list):
/// restoring a draft re-fetches GET /councils/{id}/leas rather than
/// trusting a possibly-stale cached councillor list.
class PersistedDraft extends Equatable {
  const PersistedDraft({
    this.councilId,
    this.councilName,
    this.leaId,
    this.leaName,
    this.topic,
    this.subject = '',
    this.body = '',
    required this.savedAt,
  });

  final String? councilId;
  final String? councilName;
  final String? leaId;
  final String? leaName;
  final String? topic;
  final String subject;
  final String body;
  final DateTime savedAt;

  factory PersistedDraft.fromJson(Map<String, dynamic> json) {
    return PersistedDraft(
      councilId: json['councilId'] as String?,
      councilName: json['councilName'] as String?,
      leaId: json['leaId'] as String?,
      leaName: json['leaName'] as String?,
      topic: json['topic'] as String?,
      subject: json['subject'] as String? ?? '',
      body: json['body'] as String? ?? '',
      savedAt: DateTime.parse(json['savedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': 1,
      'councilId': councilId,
      'councilName': councilName,
      'leaId': leaId,
      'leaName': leaName,
      'topic': topic,
      'subject': subject,
      'body': body,
      'savedAt': savedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [councilId, councilName, leaId, leaName, topic, subject, body, savedAt];
}
