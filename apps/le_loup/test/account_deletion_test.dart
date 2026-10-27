import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_loup/community/profile_screen.dart';

void main() {
  testWidgets(
    'La suppression exige un code et la confirmation puis ferme la session',
    (tester) async {
      final calls = <String>[];
      bool sessionClosed = false;
      Future<Map<String, dynamic>> request(
        String path, {
        String method = 'GET',
        Map<String, dynamic>? body,
      }) async {
        calls.add(path);
        if (path == 'profile') {
          return {
            'nickname': 'Alice',
            'email': 'alice@example.test',
            'account_state': 'active',
            'warning_streak': 0,
          };
        }
        if (path == 'purchases') return {'purchases': []};
        if (path == 'account-deletion/request') {
          expect(body, {'email': 'alice@example.test'});
          return {
            'challenge_id': 'test-deletion-challenge',
            'message': 'Code envoyé.',
          };
        }
        expect(body, {
          'challenge_id': 'test-deletion-challenge',
          'code': '123456',
          'confirm': true,
        });
        return {'ok': true};
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(
                      request: request,
                      onPasswordReset: () => sessionClosed = true,
                    ),
                  ),
                ),
                child: const Text('Ouvrir le profil'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir le profil'));
      await tester.pumpAndSettle();
      final deletion = find.text('Supprimer mon compte et mes données');
      await tester.scrollUntilVisible(
        deletion,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(deletion);
      await tester.pumpAndSettle();
      final send = find.text('Recevoir un code de suppression');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
      final remove = find.text('Supprimer définitivement mon compte');
      await tester.ensureVisible(remove);
    await tester.pumpAndSettle();
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(calls, isNot(contains('account-deletion/confirm')));
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '123456');
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.ensureVisible(remove);
    await tester.pumpAndSettle();
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(calls.last, 'account-deletion/confirm');
      expect(sessionClosed, isTrue);
      expect(find.text('Ouvrir le profil'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
