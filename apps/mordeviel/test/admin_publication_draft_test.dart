import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/community/admin_dashboard.dart';
import 'package:mordeviel/community/admin_drafts.dart';
import 'package:mordeviel/community/publication_dialog.dart';

Widget editor(AdminDrafts drafts, AdminRequest request, {Map? item}) =>
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => PublicationDialog(
                request: request,
                drafts: drafts,
                item: item,
              ),
            ),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
    );

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets(
    'Fermer une FAQ conserve son texte sans publier, même après réouverture',
    (tester) async {
      final calls = <String>[];
      final drafts = AdminDrafts('https://test.invalid:alice-close');
      Future<Map<String, dynamic>> request(
        String path, {
        String method = 'GET',
        Map<String, dynamic>? body,
      }) async {
        calls.add('$method $path');
        return {'id': 1};
      }

      await tester.pumpWidget(editor(drafts, request));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('FAQ').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'Question inachevée',
      );
      await tester.enterText(
        find.byType(TextField).last,
        'Réponse en cours de rédaction',
      );
      await tester.pumpAndSettle();
      // Accidental dismissal on the modal barrier.
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(PublicationDialog), findsNothing);
      expect(calls, isEmpty);
      final raw = await const FlutterSecureStorage().read(
        key:
            'mordeviel.admin.draft.${Uri.encodeComponent(drafts.scope)}.publication-new',
      );
      expect(jsonDecode(raw!)['body'], 'Réponse en cours de rédaction');
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      expect(find.text('Question inachevée'), findsOneWidget);
      expect(find.text('Réponse en cours de rédaction'), findsOneWidget);
      expect(find.text('FAQ'), findsOneWidget);
      expect(calls, isEmpty);
    },
  );

  testWidgets(
    'Publication échouée garde le brouillon, publication réussie le retire',
    (tester) async {
      final drafts = AdminDrafts('https://test.invalid:alice-publish');
      bool fail = true;
      final published = <Map<String, dynamic>>[];
      Future<Map<String, dynamic>> request(
        String path, {
        String method = 'GET',
        Map<String, dynamic>? body,
      }) async {
        expect(path, 'admin/content');
        expect(method, 'POST');
        if (fail) throw StateError('offline');
        published.add(body!);
        return {'id': 8};
      }

      await tester.pumpWidget(editor(drafts, request));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Nouvelle annonce');
      await tester.enterText(
        find.byType(TextField).last,
        'Le texte à conserver',
      );
      await tester.tap(find.text('Publier dans le jeu'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Publication non confirmée'), findsOneWidget);
      expect(
        (await drafts.read('publication-new'))?['body'],
        'Le texte à conserver',
      );
      expect(published, isEmpty);
      fail = false;
      await tester.tap(find.text('Publier dans le jeu'));
      await tester.pumpAndSettle();
      expect(published.single['title'], 'Nouvelle annonce');
      expect(find.byType(PublicationDialog), findsNothing);
      expect(await drafts.read('publication-new'), isNull);
    },
  );

  test(
    'Brouillons isolés par compte, par serveur et par publication',
    () async {
      final alice = AdminDrafts('server-one:alice');
      final bob = AdminDrafts('server-one:bob');
      final otherServer = AdminDrafts('server-two:alice');
      await alice.save('publication-4', {'title': 'Confidentiel'});
      expect(await bob.read('publication-4'), isNull);
      expect(await otherServer.read('publication-4'), isNull);
      expect(await alice.read('publication-new'), isNull);
      expect(
        (await AdminDrafts(alice.scope).read('publication-4'))?['title'],
        'Confidentiel',
      );
    },
  );

  testWidgets(
    'Les emails demandent confirmation et concernent seulement une annonce publiée',
    (tester) async {
      final sends = <String>[];
      Future<Map<String, dynamic>> request(
        String path, {
        String method = 'GET',
        Map<String, dynamic>? body,
      }) async {
        if (path == 'admin/dashboard') {
          return {
            'users': [],
            'offers': [],
            'maintenance': {
              'local_enabled': true,
              'online_enabled': true,
              'message': 'OK',
            },
          };
        }
        if (path == 'admin/tickets') return {'tickets': []};
        if (path == 'admin/reports') return {'reports': []};
        if (path.endsWith('/email')) {
          expect(path, 'admin/content/7/email');
          if (method == 'POST') sends.add(path);
          return method == 'GET'
              ? {'deliveries': {}}
              : {'queued': 3, 'already_queued': false};
        }
        return {
          'announcements': [
            {
              'id': 7,
              'kind': 'announcement',
              'title': 'Soirée publiée',
              'body': 'Visible',
            },
          ],
          'faq': [
            {'id': 9, 'kind': 'faq', 'title': 'Question', 'body': 'Réponse'},
          ],
        };
      }

      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboard(request: request, draftScope: 'email-admin'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Publications'));
      await tester.tap(find.text('Publications'));
      await tester.pumpAndSettle();
      final send = find.byTooltip(
        'Envoyer ou suivre les emails de cette annonce',
      );
      expect(send, findsOneWidget);
      await tester.tap(send);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(sends, isEmpty);
      expect(find.textContaining('Soirée publiée').last, findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmer'));
      await tester.pumpAndSettle();
      expect(sends, ['admin/content/7/email']);
      expect(find.textContaining('3 email(s) mis en file'), findsOneWidget);
    },
  );
}
