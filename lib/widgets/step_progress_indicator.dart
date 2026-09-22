import 'package:flutter/material.dart';

/// A slim, persistent progress indicator across the app's 5-step linear
/// flow (council -> LEA -> compose -> review -> connect) — deliberately
/// not shown on Result/Reconnect, which aren't steps in the wizard,
/// they're terminal/exception states reached from it.
class StepProgressIndicator extends StatelessWidget {
  const StepProgressIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.label,
  });

  final int currentStep; // 1-based
  final int totalSteps;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step $currentStep of $totalSteps · $label',
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: currentStep / totalSteps,
              minHeight: 6,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
