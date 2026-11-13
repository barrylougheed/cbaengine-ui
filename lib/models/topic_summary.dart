import 'package:equatable/equatable.dart';

/// The topic id the API uses for an email the resident wrote themselves.
/// It is not an issue to pick and never appears in GET /topics.
const customTopicId = 'custom';

/// One entry of GET /topics: an issue a resident can raise. Choosing it is the
/// whole choice: there is nothing to tick, because the server writes the
/// email's text for the issue. (The API calls issues "topics"; the app says
/// "issues".)
class TopicSummary extends Equatable {
  const TopicSummary({required this.id, required this.title});

  final String id;
  final String title;

  factory TopicSummary.fromJson(Map<String, dynamic> json) {
    return TopicSummary(id: json['id'] as String, title: json['title'] as String);
  }

  @override
  List<Object?> get props => [id, title];
}
