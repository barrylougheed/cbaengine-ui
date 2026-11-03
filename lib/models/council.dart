import 'package:equatable/equatable.dart';

/// GET /councils item.
class Council extends Equatable {
  const Council({required this.id, required this.name, this.areaCount = 0, this.councillorCount = 0});

  final String id;
  final String name;

  /// How many areas the council has, and how many councillors can be written
  /// to in them. 0 means "not known" (an API that does not send the counts).
  final int areaCount;
  final int councillorCount;

  factory Council.fromJson(Map<String, dynamic> json) {
    return Council(
      id: json['id'] as String,
      name: json['name'] as String,
      areaCount: (json['area_count'] as num?)?.toInt() ?? 0,
      councillorCount: (json['councillor_count'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, name, areaCount, councillorCount];
}
