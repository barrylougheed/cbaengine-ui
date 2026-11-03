import 'package:equatable/equatable.dart';

import 'councillor.dart';
import 'message_status.dart';
import 'status_transition.dart';

/// The shape POST /messages, GET /messages/{id}, /confirm and /send all
/// return — see app.models.message.MessageRecord.
class MessageRecord extends Equatable {
  const MessageRecord({
    required this.id,
    required this.sender,
    required this.localElectoralArea,
    required this.topics,
    required this.subject,
    required this.body,
    required this.councillors,
    required this.cbaMail,
    required this.status,
    required this.detail,
    required this.createdAt,
    required this.updatedAt,
    required this.sentAt,
    required this.statusHistory,
  });

  final String id;
  final String sender;
  final String localElectoralArea;
  /// Topic ids the email covered; ["custom"] for one the resident wrote.
  final List<String> topics;
  final String subject;
  final String body;
  final List<Councillor> councillors;
  final String cbaMail;
  final MessageStatus status;
  final String? detail;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? sentAt;
  final List<StatusTransition> statusHistory;

  factory MessageRecord.fromJson(Map<String, dynamic> json) {
    return MessageRecord(
      id: json['id'] as String,
      sender: json['sender'] as String,
      localElectoralArea: json['local_electoral_area'] as String,
      topics: List<String>.from(json['topics'] as List<dynamic>),
      subject: json['subject'] as String,
      body: json['body'] as String,
      councillors: (json['councillors'] as List<dynamic>)
          .map((c) => Councillor.fromJson(c as Map<String, dynamic>))
          .toList(),
      cbaMail: json['cba_mail'] as String,
      status: MessageStatus.fromWire(json['status'] as String),
      detail: json['detail'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      sentAt: json['sent_at'] == null ? null : DateTime.parse(json['sent_at'] as String),
      statusHistory: (json['status_history'] as List<dynamic>)
          .map((s) => StatusTransition.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    sender,
    localElectoralArea,
    topics,
    subject,
    body,
    councillors,
    cbaMail,
    status,
    detail,
    createdAt,
    updatedAt,
    sentAt,
    statusHistory,
  ];
}
