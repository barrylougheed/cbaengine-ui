import 'package:equatable/equatable.dart';

/// The topic id the API uses for an email the resident wrote themselves.
/// It is not a topic to pick and never appears in GET /topics.
const customTopicId = 'custom';

/// One entry of GET /topics: a pre-defined topic a resident can start from.
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
