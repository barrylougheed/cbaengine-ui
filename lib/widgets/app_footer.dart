import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';
import 'content_width.dart';

/// The foot of the Home page: a deep olive band that says plainly, as
/// contactyourtd.ie does, that this is an independent service, and links the
/// privacy notice.
///
/// The independence statement must stay true: it is the owner's to confirm
/// before the site goes live.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  static const independence = 'An independent service, not affiliated with the Government of Ireland.';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ColoredBox(
      color: AppColors.deepOlive,
      child: ContentWidth(
        maxWidth: ContentWidth.wide,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(independence, style: textTheme.bodySmall?.copyWith(color: AppColors.softOlive)),
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
