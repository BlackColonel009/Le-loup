import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_loup/community/community_screen.dart';
import 'package:le_loup/main.dart';

void main() {
  testWidgets('Accès communauté en haut de l’accueil', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomeScreen()));
    expect(find.byTooltip('Communauté'), findsOneWidget);
    await tester.tap(find.byTooltip('Communauté'));
    await tester.pumpAndSettle();
    expect(find.text('Le village se retrouve ici'), findsOneWidget);
    expect(find.text('Créer mon compte'), findsOneWidget);
  });
  testWidgets('Inscription simple et connexion existante', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CommunityScreen()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('J’ai déjà un compte'), 150,
      scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('J’ai déjà un compte'));
    await tester.pumpAndSettle();
    expect(find.text('Me connecter'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
