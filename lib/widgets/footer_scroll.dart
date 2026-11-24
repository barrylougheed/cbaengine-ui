import 'package:flutter/material.dart';

import 'app_footer.dart';

/// A scrolling page that ends with the footer: [child], then [footer].
///
/// The page is at least as tall as the window, and the footer is spread to the
/// bottom of that. So when [child] is short the footer sits at the foot of the
/// window instead of floating half way up it, and when [child] is long the
/// footer follows it and is reached by scrolling to the end, which is how the
/// footer behaves on Home. The buttons that move on are not in here: they sit
/// in a bar outside the scrolling (see StepPage), so Continue stays in reach.
///
/// [child] and [footer] span the whole width of the window (so the footer's
/// band runs edge to edge and the scrollbar sits at the window edge); [child]
/// puts its own content in the reading column (see ContentWidth), usually by
/// being a ContentList or padding itself with ContentWidth.gutter.
///
/// It must be given a bounded height, as a Scaffold body or an Expanded is.
class FooterScroll extends StatelessWidget {
  const FooterScroll({
    super.key,
    required this.child,
    this.footer = const AppFooter(),
    this.controller,
    this.centered = false,
  });

  /// The page above the footer.
  final Widget child;

  /// The foot of the page. The privacy notice passes [AppFooter] without its
  /// link to itself.
  final Widget footer;

  /// For a scrollbar that needs to be attached to the same controller.
  final ScrollController? controller;

  /// Puts [child] in the middle of the space above the footer, for a screen
  /// with only a little to say (a message, or a spinner while something
  /// loads), instead of at the top of it.
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, viewport) => SingleChildScrollView(
        controller: controller,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: viewport.hasBoundedHeight ? viewport.maxHeight : 0),
          child: Column(
            // Spreads whatever space is left over between the children. With
            // the content first and the footer last, it all goes between them.
            // Centred, an empty first child gets half of it and the content
            // the other half, which puts the content in the middle of the
            // space above the footer.
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (centered) const SizedBox.shrink(),
              if (centered) Center(child: child) else child,
              footer,
            ],
          ),
        ),
      ),
    );
  }
}
