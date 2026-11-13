import 'package:equatable/equatable.dart';

/// The answer of POST /topics/compose: the subject and body for the topics
/// chosen, and which variant of each topic was used.
class ComposedTopics extends Equatable {
  const ComposedTopics({
    required this.topics,
    required this.variants,
    required this.subject,
    required this.body,
    required this.footer,
    this.style,
  });

  /// The chosen topic ids, in the topic list's order.
  final List<String> topics;

  /// Topic id -> id of the variant used. Sent back to keep a topic's variant
  /// when the selection changes, and again when the message is drafted.
  final Map<String, String> variants;

  /// The id of the letter style the wording is in. Only issue emails have one:
  /// a campaign's text is written as a whole, so it comes back with none.
  final String? style;

  final String subject;
  final String body;

  /// Added under the sign-off when the email is sent. Shown read-only.
  final String footer;

  factory ComposedTopics.fromJson(Map<String, dynamic> json) {
    return ComposedTopics(
      topics: List<String>.from(json['topics'] as List<dynamic>),
      variants: Map<String, String>.from(json['variants'] as Map<String, dynamic>),
      style: json['style'] as String?,
      subject: json['subject'] as String,
      body: json['body'] as String,
      footer: json['footer'] as String,
    );
  }

  @override
  List<Object?> get props => [topics, variants, style, subject, body, footer];
}
