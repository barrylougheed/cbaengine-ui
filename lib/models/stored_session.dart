import 'package:equatable/equatable.dart';

/// The persisted shape in secure storage (TokenStorageService) — kept
/// separate from AuthState, which also carries transient status values
/// (checking/expired) that never belong on disk.
class StoredSession extends Equatable {
  const StoredSession({
    required this.token,
    required this.email,
    required this.provider,
    required this.connectedAt,
  });

  final String token;
  final String email;
  final String provider;
  final DateTime connectedAt;

  factory StoredSession.fromJson(Map<String, dynamic> json) {
    return StoredSession(
      token: json['token'] as String,
      email: json['email'] as String,
      provider: json['provider'] as String,
      connectedAt: DateTime.parse(json['connectedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {'token': token, 'email': email, 'provider': provider, 'connectedAt': connectedAt.toIso8601String()};
  }

  @override
  List<Object?> get props => [token, email, provider, connectedAt];
}
