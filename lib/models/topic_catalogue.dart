import 'package:equatable/equatable.dart';

import 'topic_summary.dart';

/// The fixed parts the server puts around the resident's text in every email.
/// Held on the server (app/config.py) and sent to the app, so the review
/// step can show the email as it will go out without copying wording.
class EmailLayout extends Equatable {
  const EmailLayout({required this.greetingFormat, required this.signOff});

  /// e.g. "Dear Councillor {name},": `{name}` is each councillor's own name.
  final String greetingFormat;

  /// e.g. "Kind regards,": the resident's name follows on the next line.
  final String signOff;

  factory EmailLayout.fromJson(Map<String, dynamic> json) {
    return EmailLayout(
      greetingFormat: json['greeting_format'] as String,
      signOff: json['sign_off'] as String,
    );
  }

  String greetingFor(String councillorName) => greetingFormat.replaceAll('{name}', councillorName);

  @override
  List<Object?> get props => [greetingFormat, signOff];
}

/// GET /topics: the topics to pick from, and how every email is laid out.
class TopicCatalogue extends Equatable {
  const TopicCatalogue({required this.topics, required this.emailLayout});

  final List<TopicSummary> topics;
  final EmailLayout emailLayout;

  factory TopicCatalogue.fromJson(Map<String, dynamic> json) {
    return TopicCatalogue(
      topics: (json['topics'] as List<dynamic>).map((t) => TopicSummary.fromJson(t as Map<String, dynamic>)).toList(),
      emailLayout: EmailLayout.fromJson(json['email_layout'] as Map<String, dynamic>),
    );
  }

  @override
  List<Object?> get props => [topics, emailLayout];
}
