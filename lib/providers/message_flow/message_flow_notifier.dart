import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exceptions.dart';
import '../../models/message_intent.dart';
import '../../utils/friendly_time.dart';
import '../core_providers.dart';
import 'message_flow_state.dart';

/// Drives create -> confirm -> send straight through with no pause in
/// between (per the implementation plan: Review's "Connect email and send" tap is
/// already the user's explicit confirmation, so nothing after a
/// successful connect needs a second one).
class MessageFlowNotifier extends Notifier<MessageFlowState> {
  @override
  MessageFlowState build() => const MessageFlowIdle();

  Future<void> startFlow({
    required String localElectoralArea,
    required MessageIntent intent,
    required List<String> topics,
    required String subject,
    required String body,
    required String senderName,
    Map<String, List<String>> proposals = const {},
    Map<String, String> templateVariants = const {},
  }) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      state = const MessageFlowCreating();
      final created = await apiClient.createMessage(
        localElectoralArea: localElectoralArea,
        intent: intent,
        topics: topics,
        proposals: proposals,
        subject: subject,
        body: body,
        senderName: senderName,
        templateVariants: templateVariants,
      );

      state = const MessageFlowConfirming();
      final confirmed = await apiClient.confirmMessage(created.id);

      state = const MessageFlowSending();
      final sent = await apiClient.sendMessage(confirmed.id);

      // A `status: "failed"` MessageRecord here is still a normal
      // result — the backend already decided the outcome; this layer
      // just passes it through for the Result screen to render.
      state = MessageFlowResult(sent);
    } on NotFoundException catch (e) {
      state = MessageFlowFailed(LeaNotFoundFailure(e.message));
    } on RateLimitedException catch (e) {
      state = MessageFlowFailed(RateLimitedFailure(_rateLimitMessage(e)));
    } on ApiException catch (e) {
      // Includes UnauthorizedException — the ApiClient's onUnauthorized
      // callback already routes the user to /reconnect via
      // authNotifierProvider.markExpired(); this state is mostly moot
      // once that redirect happens, but still needs a defined value.
      state = MessageFlowFailed(GenericFlowFailure(e.message));
    }
  }

  /// "... You can send again after 14:32 tomorrow." in the resident's own time
  /// zone when the API said when; the API's own wording when it did not.
  String _rateLimitMessage(RateLimitedException error) {
    final availableAt = error.availableAt;
    if (availableAt == null) return error.message;
    final when = describeWhen(availableAt.toLocal(), ref.read(clockProvider)());
    return "You've already sent a message in the last 24 hours. You can send again after $when.";
  }
}

final messageFlowNotifierProvider = NotifierProvider<MessageFlowNotifier, MessageFlowState>(MessageFlowNotifier.new);
