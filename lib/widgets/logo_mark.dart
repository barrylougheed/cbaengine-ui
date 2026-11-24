import 'package:flutter/material.dart';

import 'brand_tone.dart';

/// The brand mark: the sloth icon, a sloth curled into a "C". It sits at the
/// left of the header, beside the name, and is the one place the mark is drawn
/// (the favicon and install icons are made from the same artwork by
/// tool/make_icons.py).
///
/// [size] is its height; its width follows the artwork's shape. It is the
/// brand green by default, for white; ask for [BrandTone.cream] on a deep olive
/// background.
///
/// Decorative: the name beside it says what it is, so screen readers skip it.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 32, this.tone = BrandTone.green});

  final double size;
  final BrandTone tone;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Image.asset(
        'assets/brand/sloth_icon_${tone.fileSuffix}.png',
        height: size,
        // The artwork is shown far smaller than it is stored: smooth, not jagged.
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
