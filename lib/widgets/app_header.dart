import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_banner.dart';
import 'content_width.dart';

/// The top bar of every screen: white, with a hairline underneath, and the
/// olive logo and the CBAEngine wordmark at the left (the link back to the
/// start). It carries no other links: the privacy notice is linked from the
/// footer only. White rather than a coloured band because the logo olive is a
/// mid-tone that reads well on white but nearly vanishes on a dark olive.
///
/// Its content sits in the same centred column as the Home page, so on a wide
/// screen the logo lines up with the page below instead of the window edge.
/// It replaces `AppBar(title: AppBanner())` on every screen, and is passed as
/// a Scaffold's `appBar`.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppHeader({super.key});

  static const double _barHeight = 64;

  // The bar plus its hairline. (The Scaffold adds any status-bar inset.)
  @override
  Size get preferredSize => const Size.fromHeight(_barHeight + 1);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      child: DecoratedBox(
        key: const Key('app-header-bar'),
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(bottom: BorderSide(color: AppColors.hairline)),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: _barHeight,
            child: ContentWidth(
              maxWidth: ContentWidth.wide,
              // At the left and centred vertically. The name gives way first on a
              // very narrow screen or with large text.
              child: Align(alignment: Alignment.centerLeft, child: AppBanner()),
            ),
          ),
        ),
      ),
    );
  }
}
