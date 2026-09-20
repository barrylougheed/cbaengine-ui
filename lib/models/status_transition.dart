import 'package:equatable/equatable.dart';

import 'message_status.dart';

class StatusTransition extends Equatable {
  const StatusTransition({required this.status, required this.at});

  final MessageStatus status;
  final DateTime at;

  factory StatusTransition.fromJson(Map<String, dynamic> json) {
    return StatusTransition(
      status: MessageStatus.fromWire(json['status'] as String),
      at: DateTime.parse(json['at'] as String),
    );
  }

  @override
  List<Object?> get props => [status, at];
}
