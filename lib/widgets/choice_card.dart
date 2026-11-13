import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A big, outlined card for one of a few choices: an icon in a soft olive disc,
/// a title and a line of explanation, and an arrow. Used for the three things
/// you can do on Home and the two ways of writing an email.
///
/// With no [onTap] the card is shown but cannot be opened (a feature that is
/// still to come) and is tinted so it reads as unavailable; a [badge] such as
/// "Coming soon" then replaces the arrow.
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  /// A small label shown instead of the arrow, e.g. "Coming soon".
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final enabled = onTap != null;

    return Card(
      margin: EdgeInsets.zero,
      // Clipped so the ink ripple stays inside the rounded corners.
      clipBehavior: Clip.antiAlias,
      color: enabled ? AppColors.white : AppColors.mist,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A Wrap rather than a Row: with a large text size or a narrow
              // card the badge drops under the icon instead of overflowing.
              // The SizedBox makes it as wide as the card: left alone a Wrap
              // is only as wide as what is in it, and the icon and arrow would
              // sit side by side instead of at the two ends.
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 8,
                  children: [
                    _IconDisc(icon: icon, enabled: enabled),
                    if (badge != null)
                      Chip(label: Text(badge!), visualDensity: VisualDensity.compact)
                    else if (enabled)
                      const Icon(Icons.arrow_forward, color: AppColors.linkOlive),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: enabled ? AppColors.ink : AppColors.mutedText,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: textTheme.bodyMedium?.copyWith(color: AppColors.mutedText)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round soft-olive disc holding a link-olive icon; grey when unavailable.
class _IconDisc extends StatelessWidget {
  const _IconDisc({required this.icon, required this.enabled});

  final IconData icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, color: enabled ? AppColors.softOlive : AppColors.hairline),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(icon, size: 24, color: enabled ? AppColors.linkOlive : AppColors.mutedText),
      ),
    );
  }
}
