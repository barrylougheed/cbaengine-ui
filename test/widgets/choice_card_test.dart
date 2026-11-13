import 'package:app/theme/app_theme.dart';
import 'package:app/widgets/choice_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A big outlined card for one of a few choices.
void main() {
  /// Shows [card] 400px wide, as a screen's column gives it a width: a card
  /// left to size itself would shrink to its content and hide layout bugs.
  Future<void> show(WidgetTester tester, ChoiceCard card) => tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 400, child: card),
        ),
      ),
    ),
  );

  testWidgets('shows its title and explanation', (tester) async {
    await show(tester, ChoiceCard(icon: Icons.edit_outlined, title: 'Craft', subtitle: 'Write it.', onTap: () {}));

    expect(find.text('Craft'), findsOneWidget);
    expect(find.text('Write it.'), findsOneWidget);
  });

  testWidgets('calls onTap when pressed, and shows an arrow', (tester) async {
    var taps = 0;
    await show(
      tester,
      ChoiceCard(icon: Icons.edit_outlined, title: 'Craft', subtitle: 'Write it.', onTap: () => taps++),
    );

    await tester.tap(find.text('Craft'));

    expect(taps, 1);
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
  });

  testWidgets('without onTap it cannot be pressed, has no arrow, and is tinted', (tester) async {
    await show(tester, const ChoiceCard(icon: Icons.link_outlined, title: 'Link', subtitle: 'Soon.'));

    final inkWell = tester.widget<InkWell>(find.byType(InkWell));
    expect(inkWell.onTap, isNull);
    expect(find.byIcon(Icons.arrow_forward), findsNothing);
    expect(tester.widget<Card>(find.byType(Card)).color, AppColors.mist);
  });

  testWidgets('shows its badge instead of the arrow', (tester) async {
    await show(
      tester,
      const ChoiceCard(icon: Icons.link_outlined, title: 'Link', subtitle: 'Soon.', badge: 'Coming soon'),
    );

    expect(find.text('Coming soon'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward), findsNothing);
  });

  testWidgets('puts the arrow at the right-hand end of the card, the icon at the left', (tester) async {
    await show(tester, ChoiceCard(icon: Icons.edit_outlined, title: 'Craft', subtitle: 'Write it.', onTap: () {}));

    final card = tester.getRect(find.byType(Card));
    final arrow = tester.getRect(find.byIcon(Icons.arrow_forward));
    final icon = tester.getRect(find.byIcon(Icons.edit_outlined));

    // 20px of padding inside the card at each side.
    expect(card.right - arrow.right, closeTo(20, 1));
    expect(icon.left - card.left, greaterThanOrEqualTo(20));
    expect(arrow.left - icon.right, greaterThan(100)); // not tucked in beside the icon (the card is 400 wide)
  });

  testWidgets('puts the badge at the right-hand end too', (tester) async {
    await show(
      tester,
      const ChoiceCard(icon: Icons.link_outlined, title: 'Link', subtitle: 'Soon.', badge: 'Coming soon'),
    );

    final card = tester.getRect(find.byType(Card));
    final badge = tester.getRect(find.byType(Chip));

    expect(card.right - badge.right, closeTo(20, 1));
  });

  testWidgets('is white when it can be pressed', (tester) async {
    await show(tester, ChoiceCard(icon: Icons.edit_outlined, title: 'Craft', subtitle: 'Write it.', onTap: () {}));

    expect(tester.widget<Card>(find.byType(Card)).color, AppColors.white);
  });
}
