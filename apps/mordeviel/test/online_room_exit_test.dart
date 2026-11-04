import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_host/local_host.dart';
import 'package:mordeviel/audio/classic_audio.dart';
import 'package:mordeviel/design/game_theme.dart';
import 'package:mordeviel/lobby_native.dart';
import 'package:mordeviel/social/online_hub.dart';
import 'package:mordeviel/social/social_api.dart';
import 'package:mordeviel/village/village_navigation.dart';

Map<String, dynamic> roomState() => {
  ...LocalHost().snapshot,
  'code': '123456',
  'host': 'MDJ',
  'narration_profile': 'classic_male',
  'automatic_narration': false,
};

class RoomApi extends SocialApi {
  int discoveries = 0;
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? deviceToken,
  }) async {
    if (path == '/social/rooms') {
      discoveries++;
      return {'rooms': <Map>[]};
    }
    throw const SocialError(401, 'Connexion requise.');
  }
}

class TestOnlineHost extends OnlineHost {
  TestOnlineHost() : super('https://test.invalid');
  final room = roomState();
  final changes = StreamController<Map<String, dynamic>>.broadcast();
  bool closed = false, disposed = false;
  int added = 0;
  @override
  Map<String, dynamic> get snapshot => Map.of(room);
  @override
  Map<String, int> get deck => Map<String, int>.from(room['deck'] as Map);
  @override
  Stream<Map<String, dynamic>> get updates => changes.stream;
  @override
  Future<void> start({
    int port = 8080,
    String nickname = 'MDJ',
    String? bindAddress,
  }) async {}
  @override
  Future<List<String>> addresses() async => ['https://test.invalid'];
  @override
  void setNarration({required String profile, required bool automatic}) {}
  @override
  Future<void> addBots(int count) async {
    added += count;
    room['players'] = <Map<String, dynamic>>[
      for (var i = 0; i < added; i++)
        {
          'id': 'bot$i',
          'nickname': 'Bot $i',
          'house_slot': i,
          'ready': true,
          'connected': true,
          'is_bot': true,
        },
    ];
    room['bot_count'] = added;
    room['has_bots'] = true;
    changes.add(snapshot);
  }

  @override
  Future<void> closeRoom() async => closed = true;
  @override
  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    await changes.close();
  }
}

class TestPlayer extends LobbyClient {
  final changes = StreamController<Map<String, dynamic>>.broadcast();
  bool disposed = false;
  @override
  Stream<Map<String, dynamic>> get events => changes.stream;
  @override
  Future<void> connect(
    String address,
    String code,
    String nickname, {
    String appearance = 'male',
    String? communityToken,
    String? communityNickname,
  }) async {
    id = 'player';
    changes.add({
      'type': 'room.snapshot',
      ...roomState(),
      'players': [
        {
          'id': id,
          'nickname': nickname,
          'house_slot': 0,
          'ready': true,
          'connected': true,
          'appearance': appearance,
        },
      ],
    });
  }

  @override
  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    await super.dispose();
    await changes.close();
  }
}

Future<void> until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 45 && !ready(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(ready(), isTrue);
}

void main() {
  late SocialApi original;
  late RoomApi api;
  late bool muted;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    original = SocialApi.instance;
    SocialApi.instance = api = RoomApi();
    muted = ClassicAudio.instance.muted;
    ClassicAudio.instance.muted = true;
  });
  tearDown(() {
    SocialApi.instance = original;
    ClassicAudio.instance.muted = muted;
  });

  testWidgets(
    'Le MDJ voit les bots sans défiler et ferme vers les villages en ligne',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final host = TestOnlineHost();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: GameTheme.classic,
          navigatorKey: navigator,
          home: const Scaffold(body: Text('Accueil')),
        ),
      );
      unawaited(
        navigator.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => LocalLobbyScreen(
              online: true,
              initialNickname: 'MDJ',
              autoStart: true,
              hostFactory: () => host,
            ),
          ),
        ),
      );
      await until(
        tester,
        () => find.byType(VillageNavigation).evaluate().isNotEmpty,
      );
      final add = find.byKey(const ValueKey('add-room-bots'));
      expect(add, findsOneWidget);
      expect(tester.getRect(add).bottom, lessThan(740));
      await tester.tap(add);
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Compléter le salon avec des bots'), findsOneWidget);
      await tester.tap(find.text('Ajouter'));
      await until(tester, () => host.added > 0);
      expect(
        (host.room['players'] as List).every((p) => p['ready'] == true),
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 350));
      unawaited(navigator.currentState!.maybePop());
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('Quitter'));
      await until(
        tester,
        () => find.byType(OnlineHubScreen).evaluate().isNotEmpty,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(host.closed, isTrue);
      expect(find.byType(LocalLobbyScreen), findsNothing);
      expect(api.discoveries, greaterThan(0));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'La fermeture éjecte le joueur et retire aussi les écrans au-dessus du salon',
    (tester) async {
      final player = TestPlayer();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: GameTheme.classic,
          navigatorKey: navigator,
          home: const Scaffold(body: Text('Accueil')),
        ),
      );
      unawaited(
        navigator.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) => LocalLobbyScreen(
              online: true,
              initialCode: '123456',
              initialNickname: 'Joueur',
              initialAppearance: 'male',
              autoStart: true,
              clientFactory: () => player,
            ),
          ),
        ),
      );
      await until(
        tester,
        () => find.byType(VillageNavigation).evaluate().isNotEmpty,
      );
      unawaited(
        navigator.currentState!.push<void>(
          MaterialPageRoute(
            builder: (_) =>
                const Scaffold(body: Text('Discussion au-dessus du salon')),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      player.changes.add({
        'type': 'room.closed',
        'message': 'Le MDJ a fermé le salon.',
      });
      await until(
        tester,
        () => find.byType(OnlineHubScreen).evaluate().isNotEmpty,
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(LocalLobbyScreen), findsNothing);
      expect(find.text('Discussion au-dessus du salon'), findsNothing);
      expect(find.text('Les villages en ligne'), findsOneWidget);
      expect(player.disposed, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
