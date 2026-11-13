import 'package:equatable/equatable.dart';

import 'category_summary.dart';
import 'style_summary.dart';
import 'topic_summary.dart';

/// The fixed parts the server puts around the resident's text in every email.
/// Held on the server (app/config.py) and sent to the app, so the review
/// step can show the email as it will go out without copying wording.
class EmailLayout extends Equatable {
  const EmailLayout({required this.greetingFormat, required this.signOff});

  /// e.g. "Hi {name},": `{name}` is each councillor's own name.
  final String greetingFormat;

  /// e.g. "Kind regards,": the resident's name follows on the next line.
  final String signOff;

  factory EmailLayout.fromJson(Map<String, dynamic> json) {
    return EmailLayout(greetingFormat: json['greeting_format'] as String, signOff: json['sign_off'] as String);
  }

  String greetingFor(String councillorName) => greetingFormat.replaceAll('{name}', councillorName);

  @override
  List<Object?> get props => [greetingFormat, signOff];
}

/// GET /topics: what a resident picks from (categories, the issues in them, and
/// the letter styles), and how every email is laid out.
class TopicCatalogue extends Equatable {
  const TopicCatalogue({
    required this.topics,
    required this.categories,
    required this.styles,
    required this.emailLayout,
  });

  /// Every issue ready for residents, alphabetically by title.
  final List<TopicSummary> topics;

  /// The categories that have a ready issue, in the owner's order.
  final List<CategorySummary> categories;

  /// The letter styles, in display order. The first is the server's default.
  final List<StyleSummary> styles;

  final EmailLayout emailLayout;

  /// The issues in the category [categoryId], alphabetically by title.
  List<TopicSummary> topicsIn(String categoryId) => [
    for (final topic in topics)
      if (topic.category == categoryId) topic,
  ];

  factory TopicCatalogue.fromJson(Map<String, dynamic> json) {
    return TopicCatalogue(
      topics: (json['topics'] as List<dynamic>).map((t) => TopicSummary.fromJson(t as Map<String, dynamic>)).toList(),
      categories: (json['categories'] as List<dynamic>)
          .map((c) => CategorySummary.fromJson(c as Map<String, dynamic>))
          .toList(),
      styles: (json['styles'] as List<dynamic>).map((s) => StyleSummary.fromJson(s as Map<String, dynamic>)).toList(),
      emailLayout: EmailLayout.fromJson(json['email_layout'] as Map<String, dynamic>),
    );
  }

  @override
  List<Object?> get props => [topics, categories, styles, emailLayout];
}
