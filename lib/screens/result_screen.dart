import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/message_status.dart';
import '../providers/message_flow/message_flow_notifier.dart';
import '../providers/message_flow/message_flow_state.dart';

// A considered green rather than Material's stock (fairly dated-looking)
// `Colors.green` — Material 3 has no built-in "success" color role, so
// this is deliberately picked to sit well against the themed palette.
const _successColor = Color(0xFF16A34A);

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
          const _AnimatedOutcomeIcon(icon: Icons.check_circle_outline, color: _successColor),
          const SizedBox(height: 16),
          Text('Your message was sent.', style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
      MessageFlowResult(:final record) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AnimatedOutcomeIcon(icon: Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text('Your message could not be sent.', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (record.detail != null) Text(record.detail!, textAlign: TextAlign.center),
        ],
      ),
      MessageFlowFailed(:final failure) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AnimatedOutcomeIcon(icon: Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text(failure.message, textAlign: TextAlign.center),
        ],
      ),
    };
  }
}

/// A small scale + fade entrance for the terminal outcome icon — the one
/// place in the app that earns a bit of motion, since it's the payoff
/// moment of the whole flow.
class _AnimatedOutcomeIcon extends StatelessWidget {
  const _AnimatedOutcomeIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(opacity: value.clamp(0, 1), child: Transform.scale(scale: value, child: child));
      },
      child: Icon(icon, color: color, size: 56),
    );
  }
}
