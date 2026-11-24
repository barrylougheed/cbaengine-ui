import 'package:app/widgets/brand_tone.dart';
import 'package:app/widgets/brand_wordmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The sloth wordmark ("CBA", the C drawn as the sloth): a roomy version of the
/// brand for places with space, such as the footer. Green on white, cream on a
/// deep olive band.
void main() {
  Future<void> show(WidgetTester tester, Widget wordmark) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: Center(child: wordmark)),
    ),
  );

  testWidgets('is the green wordmark unless told otherwise', (tester) async {
    await show(tester, const BrandWordmark());

    expect(find.image(const AssetImage('assets/brand/sloth_wordmark_green.png')), findsOneWidget);
  });

  testWidgets('can be the cream one, for a deep olive background', (tester) async {
    await show(tester, const BrandWordmark(tone: BrandTone.cream));

    expect(find.image(const AssetImage('assets/brand/sloth_wordmark_cream.png')), findsOneWidget);
    expect(find.image(const AssetImage('assets/brand/sloth_wordmark_green.png')), findsNothing);
  });

  testWidgets('is as tall as asked, and as wide as the artwork makes it', (tester) async {
    await show(tester, const BrandWordmark(height: 40));

    final size = tester.getSize(find.byType(BrandWordmark));
    expect(size.height, 40);
    expect(size.width / size.height, closeTo(800 / 314, 0.02));
  });

  testWidgets('is announced as "CBA", the name the picture spells', (tester) async {
    final semantics = tester.ensureSemantics();
    await show(tester, const BrandWordmark());

    expect(find.bySemanticsLabel('CBA'), findsOneWidget);
    semantics.dispose();
  });
}
