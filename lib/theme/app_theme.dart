import 'package:flutter/material.dart';

/// The single seam for CBAEngine's visual identity. Plain Material for
/// v1 (no brand assets exist yet) — swap the seed color/typography here
/// when real branding is ready; nothing else in the app should need to
/// change.
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
  );
}
