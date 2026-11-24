import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import 'brand_tone.dart';
import 'brand_wordmark.dart';
import 'content_width.dart';

/// The foot of every screen: a deep olive band with the sloth wordmark, that
/// says plainly, as contactyourtd.ie does, that this is an independent service,
/// and links the privacy notice. Screens get it by scrolling to the end of the
/// page (see FooterScroll).
///
/// The independence statement must stay true: it is the owner's to confirm
/// before the site goes live.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key, this.showPrivacyLink = true});

  static const independence = 'An independent service, not affiliated with the Government of Ireland.';

  /// Whether to link the privacy notice. The notice itself leaves it out
  /// rather than link to the page you are reading.
  final bool showPrivacyLink;
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ColoredBox(
      color: AppColors.deepOlive,
      child: ContentWidth(
        maxWidth: ContentWidth.wide,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 16,
            runSpacing: 12,
            children: [
              // The wordmark, in cream so it reads on the deep olive, over the statement.
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BrandWordmark(height: 44, tone: BrandTone.cream),
                  const SizedBox(height: 12),
                  Text(independence, style: textTheme.bodySmall?.copyWith(color: AppColors.softOlive)),
                ],
              ),
              if (showPrivacyLink)
                TextButton(
                  onPressed: () => context.push('/privacy'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.white),
                  child: const Text('Privacy notice'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
