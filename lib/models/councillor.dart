import 'package:equatable/equatable.dart';

/// Full councillor detail including email — only ever appears inside an
/// authenticated MessageRecord response, never on the unauthenticated
/// picker endpoints (see CouncillorPreview for that shape).
class Councillor extends Equatable {
  const Councillor({required this.name, required this.email, required this.party});

  final String name;
  final String email;
  final String party;

  factory Councillor.fromJson(Map<String, dynamic> json) {
    return Councillor(
      name: json['name'] as String,
      email: json['email'] as String,
      party: json['party'] as String,
    );
  }

  @override
  List<Object?> get props => [name, email, party];
}
