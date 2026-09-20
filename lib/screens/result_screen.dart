import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/message_status.dart';
import '../providers/message_flow/message_flow_notifier.dart';
import '../providers/message_flow/message_flow_state.dart';

/// Step 6, terminal: renders MessageRecord.status/.detail verbatim
/// against the backend's exact wording — sent, failed, or partial
/// failure. Never a toast; this is the flow's actual outcome, reached
/// automatically once ConnectEmailScreen's auto-chain (create -> confirm
/// -> send) settles.
class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(messageFlowNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: Center(
        child: Padding(padding: const EdgeInsets.all(24), child: _body(context, state)),
      ),
    );
  }

  Widget _body(BuildContext context, MessageFlowState state) {
    return switch (state) {
      MessageFlowIdle() ||
      MessageFlowCreating() ||
      MessageFlowConfirming() ||
      MessageFlowSending() => const CircularProgressIndicator(),
      MessageFlowResult(:final record) when record.status == MessageStatus.sent => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
          const SizedBox(height: 16),
          const Text('Your message was sent.', style: TextStyle(fontSize: 18)),
        ],
      ),
      MessageFlowResult(:final record) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 48),
          const SizedBox(height: 16),
          const Text('Your message could not be sent.', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          if (record.detail != null) Text(record.detail!, textAlign: TextAlign.center),
        ],
      ),
      MessageFlowFailed(:final failure) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 48),
          const SizedBox(height: 16),
          Text(failure.message, textAlign: TextAlign.center),
        ],
      ),
    };
  }
}
