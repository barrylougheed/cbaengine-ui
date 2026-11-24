import 'package:equatable/equatable.dart';

/// One letter style of GET /topics (Direct, Urgent...):
/// the tone the resident chooses for the whole email. The server writes each
/// issue's text in it. Sent in display order; the first is the server's default.
class StyleSummary extends Equatable {
  const StyleSummary({required this.id, required this.title, required this.description});

  final String id;
  final String title;

  /// One line saying what the style sounds like, shown under its name.
  final String description;

  factory StyleSummary.fromJson(Map<String, dynamic> json) {
    return StyleSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
    );
  }

  @override
  List<Object?> get props => [id, title, description];
}
