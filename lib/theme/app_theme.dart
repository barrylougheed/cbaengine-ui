import 'package:flutter/material.dart';

/// The palette, built around the logo's olive. Every text-on-background pair
/// below is checked to be readable (WCAG AA, 4.5:1) by
/// test/theme/app_theme_test.dart, so a later tweak cannot quietly break it.
///
/// The logo olive is a mid-tone: white on it is only 4.1:1, and on the deep
/// olive it nearly disappears (2.25:1). So it is used only as a graphic (the
/// logo, decorative marks), on white. Text and buttons use the darker olives.
abstract final class AppColors {
  /// The logo colour (#748264). Graphics only, never small text.
  static const logoOlive = Color(0xFF748264);

  /// Hero band, buttons, footer, stepper. White on it is 9.2:1.
  static const deepOlive = Color(0xFF3F4B37);

  /// Links and icons on white or the mist tint. 5.8:1 on white.
  static const linkOlive = Color(0xFF5A6A4C);

  /// A pale olive tint for chips, selected rows and the hero's sub-line.
  static const softOlive = Color(0xFFE7ECE0);

  /// The page tint for quiet bands (the stat strip, callouts).
  static const mist = Color(0xFFF4F6F0);

  /// Card borders and dividers.
  static const hairline = Color(0xFFD5DBCB);

  /// A firmer olive-grey for the borders of form fields (3:1 on white, as
  /// the standard asks of controls).
  static const fieldBorder = Color(0xFF7C8574);

  /// Text.
  static const ink = Color(0xFF20261B);

  /// Secondary text. 6.4:1 on white.
  static const mutedText = Color(0xFF5A6152);

  /// The one warm accent: the thin rule under the hero, small badges.
  static const clay = Color(0xFFA8502F);

  /// Errors stay red on purpose: olive must never read as "fine".
  static const error = Color(0xFFB3261E);

  /// An olive-leaning green for "your message was sent".
  static const success = Color(0xFF2F7A4A);

  static const white = Color(0xFFFFFFFF);
}

/// Bundled with the app (pubspec.yaml's `fonts:`), never fetched at
/// runtime — see the note there.
const _fontFamily = 'Inter';

/// Corners are small and uniform (8px): cards, buttons and fields all share it.
const _radius = 8.0;

/// CBAEngine's single branding seam: one light theme, olive. There is no dark
/// theme (the app is light whatever the device is set to).
ThemeData buildAppTheme() {
  const colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.deepOlive,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.softOlive,
    onPrimaryContainer: AppColors.deepOlive,
    secondary: AppColors.linkOlive,
    onSecondary: AppColors.white,
    secondaryContainer: AppColors.softOlive,
    onSecondaryContainer: AppColors.deepOlive,
    tertiary: AppColors.clay,
    onTertiary: AppColors.white,
    tertiaryContainer: Color(0xFFF6E3DA),
    onTertiaryContainer: Color(0xFF6B2F18),
    error: AppColors.error,
    onError: AppColors.white,
    errorContainer: Color(0xFFFCE8E6),
    onErrorContainer: Color(0xFF7A1A14),
    surface: AppColors.white,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.mutedText,
    surfaceContainerLowest: AppColors.white,
    surfaceContainerLow: AppColors.mist,
    surfaceContainer: AppColors.mist,
    surfaceContainerHigh: Color(0xFFEAEEE4),
    surfaceContainerHighest: Color(0xFFE4E9DC),
    outline: AppColors.fieldBorder,
    outlineVariant: AppColors.hairline,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: AppColors.ink,
    onInverseSurface: AppColors.white,
    inversePrimary: AppColors.softOlive,
    surfaceTint: Colors.transparent,
  );

  // 16px body text (Material's default is 14) with generous leading, and bold
  // headlines with tight leading.
  final textTheme = const TextTheme(
    headlineLarge: TextStyle(fontSize: 40, height: 1.15, fontWeight: FontWeight.w700, letterSpacing: -0.8),
    headlineMedium: TextStyle(fontSize: 32, height: 1.2, fontWeight: FontWeight.w700, letterSpacing: -0.5),
    headlineSmall: TextStyle(fontSize: 24, height: 1.25, fontWeight: FontWeight.w700, letterSpacing: -0.3),
    titleLarge: TextStyle(fontSize: 22, height: 1.3, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(fontSize: 18, height: 1.35, fontWeight: FontWeight.w600),
    titleSmall: TextStyle(fontSize: 16, height: 1.4, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 18, height: 1.5),
    bodyMedium: TextStyle(fontSize: 16, height: 1.5),
    bodySmall: TextStyle(fontSize: 14, height: 1.45),
    labelLarge: TextStyle(fontSize: 15, height: 1.3, fontWeight: FontWeight.w600),
    labelMedium: TextStyle(fontSize: 13, height: 1.3, fontWeight: FontWeight.w500),
    labelSmall: TextStyle(fontSize: 12, height: 1.3, fontWeight: FontWeight.w500),
  ).apply(fontFamily: _fontFamily, bodyColor: AppColors.ink, displayColor: AppColors.ink);

  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius));

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: _fontFamily,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: AppColors.white,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleMedium?.copyWith(color: AppColors.ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.deepOlive,
        foregroundColor: AppColors.white,
        minimumSize: const Size.fromHeight(48),
        shape: shape,
        textStyle: const TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.deepOlive,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: AppColors.deepOlive),
        shape: shape,
        textStyle: const TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.linkOlive,
        shape: shape,
        textStyle: const TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: AppColors.fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: AppColors.deepOlive, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_radius),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_radius),
        side: const BorderSide(color: AppColors.hairline),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),
    listTileTheme: ListTileThemeData(
      shape: shape,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.softOlive,
      labelStyle: textTheme.labelMedium?.copyWith(color: AppColors.deepOlive),
      side: BorderSide.none,
      shape: const StadiumBorder(),
    ),
    checkboxTheme: CheckboxThemeData(
      side: const BorderSide(color: AppColors.fieldBorder, width: 1.5),
      fillColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? AppColors.deepOlive : null,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.hairline, space: 24),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.deepOlive,
      linearTrackColor: AppColors.softOlive,
    ),
  );
}
