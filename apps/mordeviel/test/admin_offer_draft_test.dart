import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/community/admin_dashboard.dart';

void main() {
  testWidgets(
    'Fermer une offre conserve son brouillon sans modifier la boutique',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      final writes = <String>[];
      Future<Map<String, dynamic>> request(
        String path, {
        String method = 'GET',
        Map<String, dynamic>? body,
      }) async {
        if (method != 'GET') writes.add(path);
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
        return {'announcements': [], 'faq': []};
      }

      await tester.pumpWidget(
        MaterialApp(
          home: AdminDashboard(request: request, draftScope: 'offer-admin'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Boutique'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Créer une offre'));
      await tester.pumpAndSettle();
      final name = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Nom',
      );
      await tester.enterText(name, 'Offre en préparation');
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Créer une offre'));
      await tester.pumpAndSettle();
      expect(find.text('Offre en préparation'), findsOneWidget);
      expect(writes, isEmpty);
    },
  );
}
