import 'package:app/theme/app_theme.dart';
import 'package:app/widgets/content_width.dart';
import 'package:app/widgets/step_progress_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The five-stage stepper at the top of each step of the flow: Write, Council,
/// Area, Review, Send. It keeps the "Step N of 5 · label" sentence (which is
/// what a screen reader reads out) and adds five bars with the stage names.
void main() {
  Future<void> show(WidgetTester tester, {int step = 2, double width = 900}) async {
    tester.view.physicalSize = Size(width, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: StepProgressIndicator(currentStep: step, totalSteps: 5, label: 'Select your council'),
        ),
      ),
    );
  }

  Color barColour(WidgetTester tester, int index) =>
      tester.widget<ColoredBox>(find.byKey(Key('step-bar-$index'))).color;

  testWidgets('says which step this is, in words', (tester) async {
    await show(tester);

    expect(find.text('Step 2 of 5 · Select your council'), findsOneWidget);
  });

  testWidgets('names the five stages of the flow', (tester) async {
    await show(tester);

    for (final name in ['Write', 'Council', 'Area', 'Review', 'Send']) {
      expect(find.text(name), findsOneWidget);
    }
  });

  testWidgets('fills the bars up to and including this step, and leaves the rest pale', (tester) async {
    await show(tester, step: 3);

    expect(barColour(tester, 0), AppColors.deepOlive);
    expect(barColour(tester, 1), AppColors.deepOlive);
    expect(barColour(tester, 2), AppColors.deepOlive);
    expect(barColour(tester, 3), AppColors.hairline);
    expect(barColour(tester, 4), AppColors.hairline);
  });

  testWidgets('draws each bar across its whole stage, 4px high, not as an invisible sliver', (tester) async {
    await show(tester, step: 2);

    final first = tester.getRect(find.byKey(const Key('step-bar-0')));
    final last = tester.getRect(find.byKey(const Key('step-bar-4')));
    final row = tester.getRect(find.byKey(const Key('step-bars')));

    expect(first.height, 4);
    // Five bars and four 6px gaps share the row: about a fifth each.
    expect(first.width, closeTo((row.width - 4 * 6) / 5, 1));
    expect(first.left, closeTo(row.left, 1));
    expect(last.right, closeTo(row.right, 1)); // the bars reach both ends of the row
  });

  testWidgets('puts the first step alone in olive', (tester) async {
    await show(tester, step: 1);

    expect(barColour(tester, 0), AppColors.deepOlive);
    expect(barColour(tester, 1), AppColors.hairline);
  });

  testWidgets('marks the current stage in bold and the others plainly', (tester) async {
    await show(tester, step: 4);

    FontWeight? weightOf(String name) => tester.widget<Text>(find.text(name)).style?.fontWeight;

    expect(weightOf('Review'), FontWeight.w700);
    expect(weightOf('Write'), isNot(FontWeight.w700));
    expect(weightOf('Send'), isNot(FontWeight.w700));
  });

  testWidgets('keeps to the reading width on a wide screen', (tester) async {
    await show(tester, width: 1600);

    final bars = tester.getRect(find.byKey(const Key('step-bars')));
    expect(bars.width, lessThanOrEqualTo(ContentWidth.form));
  });

  testWidgets('fits a phone without overflowing', (tester) async {
    await show(tester, width: 360);

    expect(tester.takeException(), isNull);
  });
}
