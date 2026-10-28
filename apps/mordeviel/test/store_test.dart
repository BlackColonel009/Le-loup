import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/main.dart';
import 'package:mordeviel/store/store_screen.dart';

void main() {
  testWidgets('Boutique sous communauté et achat indisponible', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    expect(
      tester.getCenter(find.byTooltip('Boutique')).dy,
      greaterThan(tester.getCenter(find.byTooltip('Communauté')).dy),
    );
    await tester.tap(find.byTooltip('Boutique'));
    await tester.pumpAndSettle();
    expect(find.text(shopNotice), findsOneWidget);
    final product = find.ancestor(
      of: find.text('Intense Premium'),
      matching: find.byType(Card),
    );
    final purchase = find.descendant(
      of: product,
      matching: find.widgetWithText(OutlinedButton, 'Achat à venir'),
    );
    await tester.scrollUntilVisible(
      purchase,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(purchase);
    await tester.pumpAndSettle();
    await tester.tap(purchase);
    await tester.pumpAndSettle();
    expect(find.text('Non disponible'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
