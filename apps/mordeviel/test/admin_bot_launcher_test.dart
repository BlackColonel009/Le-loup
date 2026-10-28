import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/community/community_session.dart';
import 'package:mordeviel/social/admin_bot_launcher.dart';
import 'package:mordeviel/social/social_api.dart';

class AdminApi extends SocialApi {
  bool signed = true, expired = false, unavailable = false;
  String role = 'admin';
  @override
  Future<CommunitySession?> session() async => !signed
      ? null
      : CommunitySession(
          token: 'test-session',
          nickname: 'Logan',
          expiresAt: DateTime.now().add(
            expired ? const Duration(hours: -1) : const Duration(hours: 1),
          ),
        );
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? deviceToken,
  }) async {
    expect(path, '/community/me');
    if (unavailable) throw const SocialError(503, 'Indisponible');
    return {
      'user': {'role': role, 'nickname': 'Logan'},
    };
  }
}

void main() {
  late SocialApi previous;
  late AdminApi api;
  setUp(() {
    previous = SocialApi.instance;
    api = AdminApi();
    SocialApi.instance = api;
  });
  tearDown(() => SocialApi.instance = previous);
  Future<void> show(
    WidgetTester tester, {
    int revision = 0,
    Future<void> Function(String)? onStart,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminBotLauncher(
            revision: revision,
            onStart: onStart ?? (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) =>
      tester.pumpWidget(const SizedBox.shrink());
  final button = find.byKey(const ValueKey('admin-bot-launcher'));
  testWidgets('Accès visible pour un administrateur vérifié', (tester) async {
    await show(tester);
    expect(button, findsOneWidget);
    await close(tester);
  });
  for (final state in ['guest', 'player', 'expired', 'unavailable']) {
    testWidgets('Accès masqué : $state', (tester) async {
      api.signed = state != 'guest';
      api.role = state == 'player' ? 'player' : 'admin';
      api.expired = state == 'expired';
      api.unavailable = state == 'unavailable';
      await show(tester);
      expect(button, findsNothing);
      await close(tester);
    });
  }
  testWidgets('Se met à jour après connexion puis déconnexion', (tester) async {
    api.signed = false;
    await show(tester);
    expect(button, findsNothing);
    api.signed = true;
    await show(tester, revision: 1);
    expect(button, findsOneWidget);
    api.signed = false;
    await show(tester, revision: 2);
    expect(button, findsNothing);
    await close(tester);
  });
  testWidgets('Le clic revérifie les permissions avant de lancer le test', (
    tester,
  ) async {
    var launches = 0;
    await show(
      tester,
      onStart: (_) async {
        launches++;
      },
    );
    api.role = 'player';
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(launches, 0);
    expect(button, findsNothing);
    await close(tester);
  });
  testWidgets('Le clic valide transmet le pseudo du compte', (tester) async {
    String? nickname;
    await show(
      tester,
      onStart: (name) async {
        nickname = name;
      },
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(nickname, 'Logan');
    await close(tester);
  });
}
