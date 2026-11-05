import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/community/password_reset_screen.dart';
import 'package:mordeviel/community/profile_screen.dart';

void main() {
  testWidgets('Le nouveau mot de passe exige le code reçu par email', (
    tester,
  ) async {
    final calls = <String>[];
    Future<Map<String, dynamic>> request(
      String path, {
      String method = 'GET',
      Map<String, dynamic>? body,
    }) async {
      calls.add(path);
      return {
        'challenge_id': 'test-challenge-identifier',
        'message': 'Code envoyé par email.',
      };
    }

    await tester.pumpWidget(
      MaterialApp(home: PasswordResetScreen(request: request)),
    );
    expect(find.text('Nouveau mot de passe'), findsNothing);
    await tester.tap(
      find.widgetWithText(FilledButton, 'Recevoir un code par email'),
    );
    await tester.pumpAndSettle();
    expect(calls, ['password/request']);
    await tester.scrollUntilVisible(
      find.text('Nouveau mot de passe'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Code reçu par email'), findsOneWidget);
    expect(find.text('Confirmer le nouveau mot de passe'), findsOneWidget);
  });
  testWidgets('Profil : état, email et historique réel', (tester) async {
    Future<Map<String, dynamic>> request(
      String path, {
      String method = 'GET',
      Map<String, dynamic>? body,
    }) async {
      if (path == 'profile')
        return {
          'nickname': 'Alice',
          'coin_balance': 2345,
          'bronze_balance': 0,
          'role': 'player',
          'verified': false,
          'email': 'alice@example.test',
          'email_verified': true,
          'account_state': 'active',
          'warning_streak': 0,
        };
      return {'purchases': []};
    }

    await tester.pumpWidget(MaterialApp(home: ProfileScreen(request: request)));
    await tester.pumpAndSettle();
    expect(find.text('2345'), findsOneWidget);
    expect(find.text('Lunes d’or'), findsOneWidget);
    expect(find.text('0 Lunes bronze'), findsOneWidget);
    expect(find.text('Compte actif'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('alice@example.test'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('alice@example.test'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text(
        'Aucun achat pour le moment. Découvre les offres en Lunes d’or dans la boutique.',
      ),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text(
        'Aucun achat pour le moment. Découvre les offres en Lunes d’or dans la boutique.',
      ),
      findsOneWidget,
    );
  });
}
