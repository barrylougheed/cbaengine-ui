/// What kind of email the resident is sending. The API needs it stated
/// explicitly when a message is created, and checks the rest of the request
/// against it.
enum MessageIntent {
  /// Asks councillors about chosen issues, and the proposals the resident ticked.
  issues('issues'),

  /// Written entirely by the resident.
  own('own'),

  /// Backs one of the curated campaigns.
  campaign('campaign');

  const MessageIntent(this.apiValue);

  /// The value the API uses.
  final String apiValue;
}
