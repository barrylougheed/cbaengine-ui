import 'package:equatable/equatable.dart';

/// One entry of GET /campaigns: what the Campaigns screen shows. The email text
/// is not part of it: it is fetched when the resident chooses the campaign.
class CampaignSummary extends Equatable {
  const CampaignSummary({required this.id, required this.title, required this.summary, this.link});

  final String id;
  final String title;
  final String summary;

  /// Where to read more, if the campaign has a page of its own (an https address).
  final String? link;

  factory CampaignSummary.fromJson(Map<String, dynamic> json) {
    return CampaignSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String,
      link: json['link'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, title, summary, link];
}
