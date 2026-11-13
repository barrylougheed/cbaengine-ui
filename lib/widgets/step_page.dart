import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_header.dart';
import 'content_list.dart';
import 'content_width.dart';
import 'step_progress_indicator.dart';

/// A screen in the five-stage flow that writes or reviews something: the
/// header, the stepper, a scrolling column of [children], and (optionally) an
/// [action], the button that moves on.
///
/// The action sits in a bar under the scrolling content, not in it, so that
/// Continue is always on screen however long the message is (a long draft
/// would otherwise push it out of reach).
class StepPage extends StatelessWidget {
  const StepPage({super.key, required this.step, required this.label, required this.children, this.action});

  /// Which of the five stages this is, 1 to 5.
  final int step;

  /// The stage in the screen's own words, e.g. "Write your message".
  final String label;

  final List<Widget> children;

  /// The button that moves on, shown full width in the bar at the bottom.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(),
      body: Column(
        children: [
          StepProgressIndicator(currentStep: step, totalSteps: 5, label: label),
          Expanded(child: ContentList(verticalPadding: 8, children: children)),
          if (action != null) _ActionBar(child: action!),
        ],
      ),
    );
  }
}

/// White, with a hairline above it, and the button at the width of the column.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: ContentWidth(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SizedBox(width: double.infinity, child: child),
          ),
        ),
      ),
    );
  }
}
