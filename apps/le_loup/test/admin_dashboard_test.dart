import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:le_loup/community/admin_dashboard.dart';
import 'package:le_loup/community/community_screen.dart';
import 'package:le_loup/main.dart';
import 'package:le_loup/services/maintenance.dart';

void main() {
  testWidgets('Dashboard absent avant authentification administrateur', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CommunityScreen()));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Dashboard administrateur'), findsNothing);
  });
  testWidgets('Contrôles du dashboard vérifiés par le backend', (tester) async {
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
            'online_enabled': false,
            'message': 'Maintenance',
          },
        };
      }
      if (path == 'admin/tickets') return {'tickets': []};
      if (path == 'admin/reports') return {'reports': []};
      return {'announcements': [], 'faq': []};
    }

    await tester.pumpWidget(
      MaterialApp(home: AdminDashboard(request: request)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Administration certifiée'), findsOneWidget);
    expect(find.text('Appliquer les contrôles'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Maintenance locale en cache bloque le bouton Jouer', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'maintenance.local_enabled': false,
      'maintenance.message': 'On est en petite maintenance, s’il vous plaît.',
    });
    addTearDown(() => SharedPreferences.setMockInitialValues({}));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: WelcomeScreen(
            checkMaintenance: () =>
                readMaintenance(fetch: () async => throw StateError('offline')),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Jouer en local'));
    await tester.tap(find.text('Jouer en local'));
    await tester.pumpAndSettle();
    expect(find.text('Petite maintenance'), findsOneWidget);
    expect(
      find.text('On est en petite maintenance, s’il vous plaît.'),
      findsOneWidget,
    );
  });
}
