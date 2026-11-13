import 'package:app/theme/app_theme.dart';
import 'package:app/widgets/app_banner.dart';
import 'package:app/widgets/app_footer.dart';
import 'package:app/widgets/app_header.dart';
import 'package:app/widgets/content_width.dart';
import 'package:app/widgets/logo_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

/// The pieces every screen shares: a white header with the olive logo, a
/// content column that does not stretch edge to edge on a wide screen, and a
/// footer.
void main() {
  void setViewport(WidgetTester tester, double width, [double height = 1600]) {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  group('ContentWidth', () {
    Widget host(Widget child) => MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(body: child),
    );

    testWidgets('keeps its child to the maximum width on a wide screen, centred', (tester) async {
      setViewport(tester, 1400);
      const key = Key('child');
      await tester.pumpWidget(host(const ContentWidth(child: SizedBox(key: key, height: 50))));

      final rect = tester.getRect(find.byKey(key));
      expect(rect.width, ContentWidth.form - 32); // the maximum, less the side padding
      expect(rect.center.dx, 700); // centred in a 1400px window
    });

    testWidgets('the wide variant allows more width, for the Home page', (tester) async {
      setViewport(tester, 1600);
      const key = Key('child');
      await tester.pumpWidget(
        host(
          const ContentWidth(
            maxWidth: ContentWidth.wide,
            child: SizedBox(key: key, height: 50),
          ),
        ),
      );

      expect(tester.getRect(find.byKey(key)).width, ContentWidth.wide - 32);
    });

    testWidgets('fills a phone screen, less a 16px margin each side', (tester) async {
      setViewport(tester, 390);
      const key = Key('child');
      await tester.pumpWidget(host(const ContentWidth(child: SizedBox(key: key, height: 50))));

      final rect = tester.getRect(find.byKey(key));
      expect(rect.left, 16);
      expect(rect.right, 390 - 16);
    });
  });

  group('ContentWidth.gutter', () {
    // For a scrolling list that spans the whole window (so the scrollbar sits at
    // the window edge and the wheel scrolls anywhere) but whose content stays in
    // the column: the space to leave each side of it.
    test('is the 16px margin on a phone', () {
      expect(ContentWidth.gutter(390), 16);
    });

    test('is the 16px margin when the window is exactly the column wide', () {
      expect(ContentWidth.gutter(ContentWidth.form), 16);
    });

    test('grows with the window so the content stays centred in the column', () {
      // (1600 - 720) / 2 of empty window each side, plus the 16px margin.
      expect(ContentWidth.gutter(1600), 456);
      expect(ContentWidth.gutter(1600, maxWidth: ContentWidth.wide), 296);
    });
  });

  group('AppHeader', () {
    testWidgets('shows the logo mark and the CBAEngine wordmark, and a Privacy link', (tester) async {
      await openApp(tester, FakeApi(), path: '/craft');

      expect(find.byType(AppHeader), findsOneWidget);
      expect(find.byType(LogoMark), findsOneWidget);
      expect(find.text('CBAEngine'), findsOneWidget);
      expect(find.descendant(of: find.byType(AppHeader), matching: find.text('Privacy')), findsOneWidget);
    });

    testWidgets('is white with a hairline underneath, not a coloured band', (tester) async {
      await openApp(tester, FakeApi(), path: '/craft');

      final box = tester.widget<DecoratedBox>(find.byKey(const Key('app-header-bar')));
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, AppColors.white);
      expect((decoration.border as Border).bottom.color, AppColors.hairline);
    });

    testWidgets('the Privacy link opens the privacy notice', (tester) async {
      await openApp(tester, FakeApi(), path: '/craft');

      await tester.tap(find.descendant(of: find.byType(AppHeader), matching: find.text('Privacy')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Privacy notice'), findsWidgets);
    });

    testWidgets('on a wide screen its content sits inside the maximum width, not at the window edges', (tester) async {
      await openApp(tester, FakeApi(), path: '/craft');
      setViewport(tester, 1600);
      await tester.pumpAndSettle();

      final left = tester.getTopLeft(find.byType(AppBanner)).dx;
      expect(left, greaterThan((1600 - ContentWidth.wide) / 2 - 1));
    });

    testWidgets('fits a phone without overflowing', (tester) async {
      await openApp(tester, FakeApi(), path: '/craft');
      setViewport(tester, 360, 800);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(LogoMark), findsOneWidget);
      expect(find.text('CBAEngine'), findsOneWidget);
    });
  });

  group('LogoMark', () {
    testWidgets('is drawn in the logo olive', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: Scaffold(body: LogoMark())));

      final box = tester.widget<DecoratedBox>(
        find.descendant(of: find.byType(LogoMark), matching: find.byType(DecoratedBox)),
      );
      expect((box.decoration as BoxDecoration).color, AppColors.logoOlive);
    });
  });

  group('AppFooter', () {
    testWidgets('is a deep olive band with the independence statement and a privacy link', (tester) async {
      setViewport(tester, 900);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: SingleChildScrollView(child: AppFooter())),
        ),
      );

      expect(find.text('An independent service, not affiliated with the Government of Ireland.'), findsOneWidget);
      expect(find.text('Privacy notice'), findsOneWidget);
      final band = tester.widget<ColoredBox>(
        find.descendant(of: find.byType(AppFooter), matching: find.byType(ColoredBox)).first,
      );
      expect(band.color, AppColors.deepOlive);
    });
  });
}
