import 'dart:math' as math;

import 'package:app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// The WCAG 2 contrast ratio between two colours (1:1 to 21:1). AA asks for 4.5:1
/// for normal text and 3:1 for large text and graphics.
double contrast(Color a, Color b) {
  double channel(double value) => value <= 0.03928 ? value / 12.92 : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  double luminance(Color c) => 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  final la = luminance(a);
  final lb = luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The look is olive, light only. These tests guard readability, so a later
/// tweak of the palette cannot quietly make text hard to read, and pin that
/// there is no dark theme.
void main() {
  const aa = 4.5;

  group('every pair of text and background the app uses is readable (AA, 4.5:1)', () {
    final pairs = <String, (Color, Color)>{
      'white on the deep olive (buttons, hero, footer)': (AppColors.white, AppColors.deepOlive),
      'the soft olive text on the deep olive (hero sub-line)': (AppColors.softOlive, AppColors.deepOlive),
      'the deep olive on the soft olive tint (chips, selected)': (AppColors.deepOlive, AppColors.softOlive),
      'the link olive on white': (AppColors.linkOlive, AppColors.white),
      'the link olive on the mist tint': (AppColors.linkOlive, AppColors.mist),
      'ink on white': (AppColors.ink, AppColors.white),
      'ink on the mist tint': (AppColors.ink, AppColors.mist),
      'muted text on white': (AppColors.mutedText, AppColors.white),
      'muted text on the mist tint': (AppColors.mutedText, AppColors.mist),
      'white on the clay accent': (AppColors.white, AppColors.clay),
      'white on the error red': (AppColors.white, AppColors.error),
      'white on the success green': (AppColors.white, AppColors.success),
    };
    pairs.forEach((name, colors) {
      test(name, () {
        expect(contrast(colors.$1, colors.$2), greaterThanOrEqualTo(aa));
      });
    });
  });

  group('the logo olive (#748264)', () {
    test('is the logo colour exactly', () {
      expect(AppColors.logoOlive, const Color(0xFF748264));
    });

    test('is below AA as text on white, so it is only ever used as a graphic, never for small text', () {
      expect(contrast(AppColors.logoOlive, AppColors.white), lessThan(aa));
    });

    test('would nearly vanish on the deep olive, which is why the header is white', () {
      expect(contrast(AppColors.logoOlive, AppColors.deepOlive), lessThan(3));
    });

    test('is still clearly visible on white as a graphic (3:1 for graphics)', () {
      expect(contrast(AppColors.logoOlive, AppColors.white), greaterThanOrEqualTo(3));
    });
  });

  group('the theme', () {
    test('is light, with the deep olive as the primary colour and white on it', () {
      final theme = buildAppTheme();

      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, AppColors.deepOlive);
      expect(theme.colorScheme.onPrimary, AppColors.white);
      expect(theme.colorScheme.error, AppColors.error);
    });

    test('has body text at 16px, larger than the Material default of 14', () {
      expect(buildAppTheme().textTheme.bodyMedium?.fontSize, 16);
    });

    test('uses small, uniform corners (8px) and no elevation on cards', () {
      final card = buildAppTheme().cardTheme;

      expect(card.elevation, 0);
      expect((card.shape as RoundedRectangleBorder).borderRadius, BorderRadius.circular(8));
    });

    test("the theme's own text and surface colours pass AA too", () {
      final scheme = buildAppTheme().colorScheme;

      expect(contrast(scheme.onSurface, scheme.surface), greaterThanOrEqualTo(aa));
      expect(contrast(scheme.onSurfaceVariant, scheme.surface), greaterThanOrEqualTo(aa));
      expect(contrast(scheme.onPrimaryContainer, scheme.primaryContainer), greaterThanOrEqualTo(aa));
      expect(contrast(scheme.onError, scheme.error), greaterThanOrEqualTo(aa));
    });
  });

  testWidgets('the app has no dark theme: it is light whatever the device is set to', (tester) async {
    await openApp(tester, FakeApi());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.light);
    expect(app.darkTheme, isNull);
    expect(app.theme?.brightness, Brightness.light);
  });
}
