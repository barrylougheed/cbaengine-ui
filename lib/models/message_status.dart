/// Mirrors app.models.message.MessageStatus exactly — the backend's
/// enum values are the wire format (JSON strings), not display text.
enum MessageStatus {
  draftCreated('draft_created'),
  awaitingConfirmation('awaiting_confirmation'),
  sending('sending'),
  sent('sent'),
  failed('failed');

  const MessageStatus(this.wireValue);

  final String wireValue;

  factory MessageStatus.fromWire(String value) {
    return MessageStatus.values.firstWhere(
      (status) => status.wireValue == value,
      orElse: () => throw ArgumentError('Unknown MessageStatus: $value'),
    );
  }
}
