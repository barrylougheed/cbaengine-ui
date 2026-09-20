import 'package:equatable/equatable.dart';

import 'councillor_preview.dart';

/// GET /councils/{id}/leas and GET /leas item.
class Lea extends Equatable {
  const Lea({required this.id, required this.name, required this.council, required this.councillors});

  final String id;
  final String name;
  final String council;
  final List<CouncillorPreview> councillors;

  factory Lea.fromJson(Map<String, dynamic> json) {
    return Lea(
      id: json['id'] as String,
      name: json['name'] as String,
      council: json['council'] as String,
      councillors: (json['councillors'] as List<dynamic>)
          .map((c) => CouncillorPreview.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [id, name, council, councillors];
}
