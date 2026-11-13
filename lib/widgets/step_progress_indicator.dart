import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'content_width.dart';

/// A persistent five-stage stepper across the app's linear flow
/// (write -> council -> area -> review -> send). Deliberately not shown on
/// Result/Reconnect, which aren't steps in the wizard, they're
/// terminal/exception states reached from it.
///
/// Above the bars sits the sentence "Step N of 5 · label": it is what a screen
/// reader announces, and it names the step in the screen's own words. The bars
/// and stage names below are for the eye, so they are hidden from screen
/// readers rather than read out twice.
class StepProgressIndicator extends StatelessWidget {
  const StepProgressIndicator({super.key, required this.currentStep, required this.totalSteps, required this.label});

  /// The short name of each stage, in order. Only as many as [totalSteps] are shown.
  static const stageNames = ['Write', 'Council', 'Area', 'Review', 'Send'];

  final int currentStep; // 1-based
  final int totalSteps;
  final String label;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ContentWidth(
      child: Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Step $currentStep of $totalSteps · $label',
              style: textTheme.labelLarge?.copyWith(color: AppColors.mutedText),
            ),
            const SizedBox(height: 10),
            ExcludeSemantics(
              child: Row(
                key: const Key('step-bars'),
                children: [
                  for (var i = 0; i < totalSteps; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: _Stage(index: i, isDone: i < currentStep, isCurrent: i == currentStep - 1),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One stage: a bar (deep olive once reached, pale before) and its name
/// underneath, in bold for the stage you are on.
class _Stage extends StatelessWidget {
  const _Stage({required this.index, required this.isDone, required this.isCurrent});

  final int index;
  final bool isDone;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final names = StepProgressIndicator.stageNames;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          // A childless ColoredBox is only as wide as the smallest it is
          // allowed to be, so the width is set explicitly: as wide as the stage.
          child: SizedBox(
            width: double.infinity,
            height: 4,
            child: ColoredBox(key: Key('step-bar-$index'), color: isDone ? AppColors.deepOlive : AppColors.hairline),
          ),
        ),
        const SizedBox(height: 6),
        if (index < names.length)
          Text(
            names[index],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelMedium?.copyWith(
              color: isCurrent ? AppColors.deepOlive : AppColors.mutedText,
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
      ],
    );
  }
}
