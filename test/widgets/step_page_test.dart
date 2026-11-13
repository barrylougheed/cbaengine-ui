import 'package:app/theme/app_theme.dart';
import 'package:app/widgets/step_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The frame of the screens that write or review: stepper, a scrolling column,
/// and a button bar that stays on screen.
void main() {
  /// Shows [page] as the only route of a router (its header reads the router and
  /// the draft, so it cannot stand alone), in a window [height] pixels tall.
  Future<void> show(WidgetTester tester, StepPage page, {double height = 900}) async {
    tester.view.physicalSize = Size(900, height);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (context, state) => page)],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(theme: buildAppTheme(), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
  }

  Widget continueButton({VoidCallback? onPressed}) =>
      FilledButton(onPressed: onPressed ?? () {}, child: const Text('Continue'));

  testWidgets('shows the stepper and the content', (tester) async {
    await show(tester, const StepPage(step: 2, label: 'Select your council', children: [Text('Body text')]));

    expect(find.text('Step 2 of 5 · Select your council'), findsOneWidget);
    expect(find.text('Body text'), findsOneWidget);
  });

  testWidgets('keeps the action at the bottom of the window, below the content', (tester) async {
    await show(
      tester,
      StepPage(step: 1, label: 'Write your message', action: continueButton(), children: const [Text('Short')]),
    );

    final button = tester.getRect(find.widgetWithText(FilledButton, 'Continue'));
    expect(button.bottom, lessThanOrEqualTo(900));
    expect(button.bottom, greaterThan(850)); // at the foot of the window, not up beside the text
  });

  testWidgets('keeps the action on screen when the content is far taller than the window', (tester) async {
    await show(
      tester,
      StepPage(
        step: 1,
        label: 'Write your message',
        action: continueButton(),
        children: [for (var i = 0; i < 80; i++) Text('Line $i')],
      ),
      height: 600,
    );

    expect(tester.getRect(find.widgetWithText(FilledButton, 'Continue')).bottom, lessThanOrEqualTo(600));
  });

  testWidgets('presses the action', (tester) async {
    var pressed = false;
    await show(
      tester,
      StepPage(
        step: 1,
        label: 'Write your message',
        action: continueButton(onPressed: () => pressed = true),
        children: const [Text('Body')],
      ),
    );

    await tester.tap(find.text('Continue'));

    expect(pressed, isTrue);
  });

  testWidgets('has no action bar when there is no action', (tester) async {
    await show(tester, const StepPage(step: 1, label: 'Write your message', children: [Text('Body')]));

    expect(find.byType(FilledButton), findsNothing);
  });
}
