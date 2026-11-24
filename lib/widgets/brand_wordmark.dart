import 'package:flutter/material.dart';

import 'brand_tone.dart';

/// The sloth wordmark: "CBA" with the sloth as the C. A roomy version of the
/// brand, for places with space (the footer); the header uses the smaller
/// [LogoMark] beside the name.
///
/// [height] is its height; its width follows the artwork's shape. Green on
/// white by default, [BrandTone.cream] on a deep olive background.
///
/// Announced to screen readers as "CBA", the name the picture spells.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.height = 40, this.tone = BrandTone.green});

  final double height;
  final BrandTone tone;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/sloth_wordmark_${tone.fileSuffix}.png',
      height: height,
      semanticLabel: 'CBA',
      // The artwork is shown far smaller than it is stored: smooth, not jagged.
      filterQuality: FilterQuality.medium,
    );
  }
}
