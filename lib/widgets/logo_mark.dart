import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The brand mark: an olive disc with a white envelope. It stands in for the
/// final logo, which is placed here in one spot when it is ready (replace the
/// body of [build] with an `Image.asset`). It always sits on white, where the
/// logo olive reads clearly (4.1:1, fine for a graphic).
///
/// Decorative: the wordmark beside it carries the name, so screen readers
/// skip it.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: AppColors.logoOlive, shape: BoxShape.circle),
          child: Icon(Icons.mail_outline, size: size * 0.56, color: AppColors.white),
        ),
      ),
    );
  }
}
