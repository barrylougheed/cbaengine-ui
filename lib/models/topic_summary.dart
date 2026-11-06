import 'package:equatable/equatable.dart';

/// The topic id the API uses for an email the resident wrote themselves.
/// It is not an issue to pick and never appears in GET /topics.
const customTopicId = 'custom';

/// One thing a resident can ask their councillors to support. [text] completes
/// "Would you support ...?", so it is a phrase, not a sentence.
class ProposalSummary extends Equatable {
  const ProposalSummary({required this.id, required this.text});

  final String id;
  final String text;

  factory ProposalSummary.fromJson(Map<String, dynamic> json) {
    return ProposalSummary(id: json['id'] as String, text: json['text'] as String);
  }

  @override
  List<Object?> get props => [id, text];
}

/// One entry of GET /topics: an issue a resident can raise, with the proposals
/// they can tick. (The API calls issues "topics"; the app says "issues".)
class TopicSummary extends Equatable {
  const TopicSummary({required this.id, required this.title, this.proposals = const []});

  final String id;
  final String title;
  final List<ProposalSummary> proposals;

  factory TopicSummary.fromJson(Map<String, dynamic> json) {
    return TopicSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      proposals: [
        for (final proposal in json['proposals'] as List<dynamic>? ?? const [])
          ProposalSummary.fromJson(proposal as Map<String, dynamic>),
      ],
    );
  }

  @override
  List<Object?> get props => [id, title, proposals];
}
