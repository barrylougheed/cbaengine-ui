import 'package:flutter/material.dart';

import 'content_width.dart';

/// A scrolling list of [children] whose content sits in the centred reading
/// column. The list itself spans the whole window, so the scrollbar sits at the
/// window edge and the mouse wheel scrolls anywhere on the page; only the
/// margins grow with the window (see [ContentWidth.gutter]).
///
/// It is what the screens of the flow put their content in, in place of a bare
/// `ListView` with a fixed 16px padding.
class ContentList extends StatelessWidget {
  const ContentList({super.key, required this.children, this.maxWidth = ContentWidth.form, this.verticalPadding = 16});

  final List<Widget> children;

  /// The width of the column the content sits in.
  final double maxWidth;

  /// Space above the first child and below the last.
  final double verticalPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => ListView(
        padding: EdgeInsets.symmetric(
          horizontal: ContentWidth.gutter(constraints.maxWidth, maxWidth: maxWidth),
          vertical: verticalPadding,
        ),
        children: children,
      ),
    );
  }
}
