import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mordeviel/joining/room_nickname_dialog.dart';
import 'package:mordeviel/social/presence_badge.dart';
import 'package:mordeviel/social/social_api.dart';
import 'package:mordeviel/social/social_service.dart';

class PresenceApi extends SocialApi {
  final states = <String>[];
  final acknowledged = <String>[];
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? deviceToken,
  }) async {
    if (path == '/social/summary') {
      return {
        'user_id': 1,
        'friend_requests': 0,
        'invitations': 0,
        'phone_notifications': false,
      };
    }
    if (path == '/social/presence') {
      states.add(body!['state'] as String);
      return {'ok': true};
    }
    if (path.startsWith('/social/presence/alerts?')) {
      return {
        'alerts': [
          {'id': 7, 'nickname': 'Logan', 'created': 1793251200},
        ],
      };
    }
    if (path.endsWith('/delivered')) {
      acknowledged.add(path);
      return {'ok': true};
    }
    return {};
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('Le pseudo est validé et redemandé à chaque nouvelle entrée', (
    tester,
  ) async {
    final names = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                final alias = await chooseRoomNickname(context);
                if (alias != null) names.add(alias);
              },
              child: const Text('Rejoindre'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Rejoindre'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Entrer dans le village'));
    await tester.pumpAndSettle();
    expect(
      find.text('Choisis un pseudo de 1 à 24 caractères.'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('room-nickname')),
      '  Le Masque  ',
    );
    await tester.tap(find.text('Entrer dans le village'));
    await tester.pumpAndSettle();
    expect(names, ['Le Masque']);
    await tester.tap(find.text('Rejoindre'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('room-nickname')))
          .controller!
          .text,
      isEmpty,
    );
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(names, ['Le Masque']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'La présence suit le premier plan et les alertes ne se répètent pas',
    (tester) async {
      final original = SocialApi.instance;
      final api = PresenceApi();
      SocialApi.instance = api;
      addTearDown(() => SocialApi.instance = original);
      final service = SocialService();
      await service.refresh();
      expect(api.states.last, 'online');
      expect(
        service.takePresenceAnnouncement(),
        contains('Logan s’est connecté'),
      );
      expect(api.acknowledged, ['/social/presence/alerts/7/delivered']);
      await service.refresh();
      expect(service.takePresenceAnnouncement(), isNull);
      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      expect(api.states.last, 'away');
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(api.states.last, 'online');
      await service.logout();
      expect(api.states.last, 'offline');
      service.dispose();
    },
  );

  testWidgets('Les trois badges restent lisibles sur un petit écran', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                FriendPresenceBadge(person: {'presence': 'online'}),
                FriendPresenceBadge(person: {'presence': 'away'}),
                FriendPresenceBadge(
                  person: {
                    'presence': 'offline',
                    'disconnected_at': 1793251200,
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Connecté'), findsOneWidget);
    expect(find.text('Absent'), findsOneWidget);
    expect(find.textContaining('Déconnecté depuis le'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
