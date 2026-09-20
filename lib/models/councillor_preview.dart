import 'package:equatable/equatable.dart';

/// Name and party only — deliberately never an email address, matching
/// the backend's unauthenticated `GET /councils/{id}/leas` /
/// `GET /leas` response shape (app/routers/leas.py's CouncillorPreview).
class CouncillorPreview extends Equatable {
  const CouncillorPreview({required this.name, required this.party});

  final String name;
  final String party;

  factory CouncillorPreview.fromJson(Map<String, dynamic> json) {
    return CouncillorPreview(name: json['name'] as String, party: json['party'] as String);
  }

  @override
  List<Object?> get props => [name, party];
}
