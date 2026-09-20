import 'package:equatable/equatable.dart';

/// GET /councils item.
class Council extends Equatable {
  const Council({required this.id, required this.name});

  final String id;
  final String name;

  factory Council.fromJson(Map<String, dynamic> json) {
    return Council(id: json['id'] as String, name: json['name'] as String);
  }

  @override
  List<Object?> get props => [id, name];
}
