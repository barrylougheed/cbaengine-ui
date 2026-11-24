import 'package:app/theme/app_theme.dart';
import 'package:app/widgets/app_footer.dart';
import 'package:app/widgets/footer_scroll.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// [FooterScroll] is a scrolling page with the footer at its end: straight
/// after the content when the content is long, and at the foot of the window
/// when it is short, so no screen has a footer floating half way up.
void main() {
  const windowHeight = 800.0;

  /// Puts [body] in a window [width] wide and 800 high (the footer is a deep
  /// olive band that uses the app theme).
  Future<void> show(WidgetTester tester, Widget body, {double width = 900}) async {
    tester.view.physicalSize = Size(width, windowHeight);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(body: body),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// A box [height] tall, so a test knows exactly how tall the content is.
  Widget box(double height, {Key? key}) => SizedBox(key: key, height: height);

  group('with content that is shorter than the window', () {
    testWidgets('the footer sits at the foot of the window', (tester) async {
      await show(tester, FooterScroll(child: box(100, key: const Key('content'))));

      expect(tester.getBottomLeft(find.byType(AppFooter)).dy, windowHeight);
      expect(tester.getTopLeft(find.byKey(const Key('content'))).dy, 0); // the content stays at the top
    });

    testWidgets('the footer spans the whole window, not just the reading column', (tester) async {
      await show(tester, FooterScroll(child: box(100)), width: 1600);

      expect(tester.getSize(find.byType(AppFooter)).width, 1600);
    });

    testWidgets('the content spans the whole window too, to lay itself out in the column it wants', (tester) async {
      await show(tester, FooterScroll(child: box(100, key: const Key('content'))), width: 1600);

      expect(tester.getSize(find.byKey(const Key('content'))).width, 1600);
    });

    testWidgets('there is nothing to scroll', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await show(tester, FooterScroll(controller: controller, child: box(100)));

      expect(controller.position.maxScrollExtent, 0);
    });
  });

  group('with content that is taller than the window', () {
    testWidgets('the footer is below the window until the end of the content is reached', (tester) async {
      await show(tester, FooterScroll(child: box(3000)));

      expect(tester.getTopLeft(find.byType(AppFooter)).dy, greaterThanOrEqualTo(windowHeight));
    });

    testWidgets('scrolling to the end shows the footer directly under the content', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await show(
        tester,
        FooterScroll(
          controller: controller,
          child: box(3000, key: const Key('content')),
        ),
      );

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();

      expect(tester.getBottomLeft(find.byType(AppFooter)).dy, windowHeight); // the very end of the page
      // No gap between the content and the footer.
      expect(tester.getBottomLeft(find.byKey(const Key('content'))).dy, tester.getTopLeft(find.byType(AppFooter)).dy);
    });
  });

  group('centered', () {
    testWidgets('puts the child in the middle of the space above the footer', (tester) async {
      await show(
        tester,
        const FooterScroll(centered: true, child: SizedBox(key: Key('middle'), width: 100, height: 100)),
      );

      final footerTop = tester.getTopLeft(find.byType(AppFooter)).dy;
      final middle = tester.getRect(find.byKey(const Key('middle')));
      expect(tester.getBottomLeft(find.byType(AppFooter)).dy, windowHeight);
      expect(middle.center.dx, 450); // centred across the window
      expect(middle.center.dy, closeTo(footerTop / 2, 0.5)); // and down the space above the footer
    });

    testWidgets('scrolls to the footer when the child is taller than the window', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await show(tester, FooterScroll(centered: true, controller: controller, child: box(2000)));

      expect(controller.position.maxScrollExtent, greaterThan(0));
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();

      expect(tester.getBottomLeft(find.byType(AppFooter)).dy, windowHeight);
    });
  });

  group('the footer', () {
    testWidgets('is the app footer unless another is given', (tester) async {
      await show(tester, FooterScroll(child: box(100)));

      expect(find.byType(AppFooter), findsOneWidget);
      expect(find.text('Privacy notice'), findsOneWidget);
    });

    testWidgets('can be another one, such as the footer without the privacy link', (tester) async {
      await show(tester, FooterScroll(footer: const AppFooter(showPrivacyLink: false), child: box(100)));

      expect(find.byType(AppFooter), findsOneWidget);
      expect(find.text('Privacy notice'), findsNothing);
    });

    testWidgets('does not overflow on a phone', (tester) async {
      await show(tester, FooterScroll(child: box(100)), width: 360);

      expect(tester.takeException(), isNull);
      expect(tester.getBottomLeft(find.byType(AppFooter)).dy, windowHeight);
    });
  });

  testWidgets('uses the controller it is given, so a scrollbar can be attached to it', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await show(tester, FooterScroll(controller: controller, child: box(100)));

    expect(controller.hasClients, isTrue);
  });
}
