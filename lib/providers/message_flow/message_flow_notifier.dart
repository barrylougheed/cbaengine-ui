import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_exceptions.dart';
import '../core_providers.dart';
import 'message_flow_state.dart';

/// Drives create -> confirm -> send straight through with no pause in
/// between (per the implementation plan: Review's "Continue" tap is
/// already the user's explicit confirmation, so nothing after a
/// successful connect needs a second one).
class MessageFlowNotifier extends Notifier<MessageFlowState> {
  @override
  MessageFlowState build() => const MessageFlowIdle();

  Future<void> startFlow({
    required String localElectoralArea,
    required List<String> topics,
    required String subject,
    required String body,
    required String senderName,
    Map<String, String> templateVariants = const {},
  }) async {
    final apiClient = ref.read(apiClientProvider);
    try {
      state = const MessageFlowCreating();
      final created = await apiClient.createMessage(
        localElectoralArea: localElectoralArea,
        topics: topics,
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
      state = MessageFlowFailed(RateLimitedFailure(e.message));
    } on ApiException catch (e) {
      // Includes UnauthorizedException — the ApiClient's onUnauthorized
      // callback already routes the user to /reconnect via
      // authNotifierProvider.markExpired(); this state is mostly moot
      // once that redirect happens, but still needs a defined value.
      state = MessageFlowFailed(GenericFlowFailure(e.message));
    }
  }
}

final messageFlowNotifierProvider = NotifierProvider<MessageFlowNotifier, MessageFlowState>(MessageFlowNotifier.new);
