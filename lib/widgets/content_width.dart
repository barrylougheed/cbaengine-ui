import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Centres its child and stops it stretching across a wide screen: the content
/// of every screen sits in a column of at most [maxWidth], with a 16px margin
/// each side, which on a phone is simply the screen width less the margin.
///
/// Forms and the steps of the flow use [form] (about 70 characters of text per
/// line, which is the most that reads comfortably); the Home page, header and
/// footer use [wide].
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = form});

  /// The reading width for forms, steps and articles.
  static const double form = 720;

  /// The width of the Home page, header and footer.
  static const double wide = 1040;

  /// The space kept clear at each side of the column.
  static const double margin = 16;

  /// The space to leave each side of a scrolling list so that its content sits
  /// in the column while the list itself spans [availableWidth], the whole
  /// window. (A list inside a [ContentWidth] would scroll only over the column:
  /// the wheel would do nothing beside it and the scrollbar would float in
  /// mid-page.) It is [margin] when the window is no wider than the column.
  static double gutter(double availableWidth, {double maxWidth = form}) =>
      (availableWidth - math.min(maxWidth, availableWidth)) / 2 + margin;

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The column is exactly [maxWidth] wide, or the whole screen when that is
    // narrower, so the content fills it (a plain ConstrainedBox would only cap
    // the width and let a Column shrink to its widest line).
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(maxWidth, constraints.maxWidth);
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: margin),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
