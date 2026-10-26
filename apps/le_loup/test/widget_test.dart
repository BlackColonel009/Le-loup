import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:le_loup/main.dart';

void main() {
  testWidgets('L’accueil présente le projet', (tester) async {
    await tester.pumpWidget(const LeLoupApp());
    expect(find.text('Le Loup'), findsOneWidget);
    expect(find.text('Notre première étape'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Le salon valide le pseudo avant d’héberger', (tester) async {
    await tester.pumpWidget(const LeLoupApp());
    await tester.tap(find.text('Jouer en local'));
    await tester.pumpAndSettle();
    expect(find.text('Rassemble ton village'), findsOneWidget);
    await tester.tap(find.text('Créer un salon · Je suis le MDJ'));
    await tester.pump();
    expect(
      find.text('Choisis un pseudo de 1 à 24 caractères.'),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsNWidgets(3));
  });
}
