import 'package:flutter/material.dart';

import 'app_footer.dart';
import 'content_width.dart';
import 'footer_scroll.dart';

/// A scrolling page whose [children] sit in the centred reading column, with
/// the footer at the end (see [FooterScroll]). The page itself spans the whole
/// window, so its scrollbar sits at the window edge and the mouse wheel scrolls
/// anywhere on it; only the margins grow with the window (see
/// [ContentWidth.gutter]).
///
/// It is what the screens of the flow put their content in, in place of a bare
/// `ListView` with a fixed 16px padding.
class ContentList extends StatelessWidget {
  const ContentList({
    super.key,
    required this.children,
    this.maxWidth = ContentWidth.form,
    this.verticalPadding = 16,
    this.footer = const AppFooter(),
  });

  final List<Widget> children;

  /// The width of the column the content sits in.
  final double maxWidth;

  /// Space above the first child and below the last.
  final double verticalPadding;

  /// The foot of the page. The privacy notice leaves out its own link.
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => FooterScroll(
        footer: footer,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: ContentWidth.gutter(constraints.maxWidth, maxWidth: maxWidth),
            vertical: verticalPadding,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ),
    );
  }
}
