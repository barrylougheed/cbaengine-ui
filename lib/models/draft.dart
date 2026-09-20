import 'package:equatable/equatable.dart';

import 'council.dart';
import 'lea.dart';

/// The in-progress message the user is building — held in
/// draftNotifierProvider as the user moves through council -> LEA ->
/// compose -> review. Nothing here is sent to the backend until
/// /connect's auto-chain (create -> confirm -> send) runs, so this is
/// pure client-side state.
class Draft extends Equatable {
  const Draft({this.council, this.lea, this.topic, this.subject = '', this.body = ''});

  final Council? council;
  final Lea? lea;
  final String? topic;
  final String subject;
  final String body;

  Draft copyWith({
    Council? council,
    bool clearLea = false,
    Lea? lea,
    String? topic,
    String? subject,
    String? body,
  }) {
    return Draft(
      council: council ?? this.council,
      lea: clearLea ? null : (lea ?? this.lea),
      topic: topic ?? this.topic,
      subject: subject ?? this.subject,
      body: body ?? this.body,
    );
  }

  bool get isReadyToReview => lea != null && topic != null && subject.trim().isNotEmpty && body.trim().isNotEmpty;

  @override
  List<Object?> get props => [council, lea, topic, subject, body];
}
