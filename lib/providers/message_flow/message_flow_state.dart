import 'package:equatable/equatable.dart';

import '../../models/message_record.dart';

sealed class FlowFailure extends Equatable {
  const FlowFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}

class LeaNotFoundFailure extends FlowFailure {
  const LeaNotFoundFailure(super.message);
}

class RateLimitedFailure extends FlowFailure {
  const RateLimitedFailure(super.message);
}

class GenericFlowFailure extends FlowFailure {
  const GenericFlowFailure(super.message);
}

sealed class MessageFlowState extends Equatable {
  const MessageFlowState();

  @override
  List<Object?> get props => [];
}

class MessageFlowIdle extends MessageFlowState {
  const MessageFlowIdle();
}

class MessageFlowCreating extends MessageFlowState {
  const MessageFlowCreating();
}

class MessageFlowConfirming extends MessageFlowState {
  const MessageFlowConfirming();
}

class MessageFlowSending extends MessageFlowState {
  const MessageFlowSending();
}

/// Terminal on success — reached whether the backend's own outcome was
/// `sent` or `failed` (a `status: "failed"` MessageRecord is a normal
/// 200 return, not an exception; the Result screen renders based on
/// `.status`/`.detail`, see the implementation plan).
class MessageFlowResult extends MessageFlowState {
  const MessageFlowResult(this.record);

  final MessageRecord record;

  @override
  List<Object?> get props => [record];
}

/// Terminal on a request that never reached a MessageRecord at all
/// (couldn't even create/confirm/send the draft).
class MessageFlowFailed extends MessageFlowState {
  const MessageFlowFailed(this.failure);

  final FlowFailure failure;

  @override
  List<Object?> get props => [failure];
}
