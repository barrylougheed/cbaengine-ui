import 'package:flutter/material.dart';

/// CBAEngine's single branding seam. Material 3 throughout — the brief
/// is "modern and immediately familiar", not a bespoke visual language,
/// so this stays inside M3 conventions and only tunes what actually
/// signals "designed" rather than "default Flutter app": typeface, seed
/// color, and a handful of component shapes.
const _seedColor = Color(0xFF1D4ED8); // a considered civic blue, not Material's stock indigo

/// Bundled with the app (pubspec.yaml's `fonts:`), never fetched at
/// runtime — see the note there.
const _fontFamily = 'Inter';

ThemeData buildAppTheme({required Brightness brightness}) {
  final colorScheme = ColorScheme.fromSeed(seedColor: _seedColor, brightness: brightness);
  final baseTextTheme = brightness == Brightness.dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
  final textTheme = baseTextTheme.apply(fontFamily: _fontFamily);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: _fontFamily,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: colorScheme.onSurface),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontFamily: _fontFamily, fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 4),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    dividerTheme: DividerThemeData(color: colorScheme.outlineVariant, space: 32),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: colorScheme.primary),
  );
}
