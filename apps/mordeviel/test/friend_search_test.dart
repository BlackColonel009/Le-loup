import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mordeviel/design/game_theme.dart';
import 'package:mordeviel/social/social_api.dart';
import 'package:mordeviel/social/friend_search_screen.dart';

Map<String, dynamic> person(
  int id,
  String name, {
  String relationship = 'none',
  bool incoming = false,
}) => {
  'id': id,
  'nickname': name,
  'avatar': null,
  'verified': false,
  'relationship': relationship,
  'is_friend': relationship == 'accepted',
  'request_incoming': incoming,
};

class SearchApi extends SocialApi {
  final players = [
    person(2, 'Logan'),
    person(3, 'Logan Deux', relationship: 'pending'),
    person(4, 'Logan Trois', relationship: 'pending', incoming: true),
    person(5, 'Logan Quatre', relationship: 'accepted'),
  ];
  final actions = <String>[];
  final requests = <String, Completer<Map<String, dynamic>>>{};
  bool delayed = false;
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? deviceToken,
  }) async {
    final uri = Uri.parse(path);
    if (uri.path == '/social/players/search') {
      final query = uri.queryParameters['q']!;
      if (delayed) {
        return (requests[query] = Completer<Map<String, dynamic>>()).future;
      }
      return {
        'players': [for (final p in players) Map<String, dynamic>.from(p)],
      };
    }
    if (path.startsWith('/social/friends/')) {
      final id = int.parse(path.split('/').last);
      final action = body!['action'];
      actions.add('$id:$action');
      final player = players.firstWhere((p) => p['id'] == id);
      player['relationship'] = action == 'accept' ? 'accepted' : 'pending';
      player['is_friend'] = action == 'accept';
      player['request_incoming'] = false;
      return {'ok': true};
    }
    throw const SocialError(401, 'Connexion requise.');
  }
}

void main() {
  late SocialApi original;
  late SearchApi api;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    original = SocialApi.instance;
    SocialApi.instance = api = SearchApi();
  });
  tearDown(() => SocialApi.instance = original);

  testWidgets(
    'Recherche par pseudo, ajout, attente et acceptation sur petit écran',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(theme: GameTheme.classic, home: const FriendSearchScreen()),
      );
      final input = find.byKey(const ValueKey('friend-search-input'));
      await tester.enterText(input, 'Lo');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('Logan'), findsOneWidget);
      await tester.tap(find.text('Ajouter en ami'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(api.actions, ['2:request']);
      final sent = find.widgetWithText(FilledButton, 'Demande envoyée');
      expect(sent, findsNWidgets(2));
      for (final element in sent.evaluate()) {
        expect((element.widget as FilledButton).onPressed, isNull);
      }
      await tester.scrollUntilVisible(
        find.text('Accepter la demande'),
        180,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(find.text('Accepter la demande'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(api.actions, ['2:request', '4:accept']);
      expect(find.text('Accepter la demande'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Une ancienne réponse ne remplace pas la recherche courante', (
    tester,
  ) async {
    api.delayed = true;
    await tester.pumpWidget(
      MaterialApp(theme: GameTheme.classic, home: const FriendSearchScreen()),
    );
    final input = find.byKey(const ValueKey('friend-search-input'));
    await tester.enterText(input, 'Lo');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(input, 'Ko');
    await tester.pump(const Duration(milliseconds: 400));
    api.requests['Ko']!.complete({
      'players': [person(6, 'Kossi')],
    });
    await tester.pump();
    expect(find.text('Kossi'), findsOneWidget);
    api.requests['Lo']!.complete({
      'players': [person(2, 'Logan')],
    });
    await tester.pump();
    expect(find.text('Kossi'), findsOneWidget);
    expect(find.text('Logan'), findsNothing);
    await tester.tap(find.byTooltip('Effacer la recherche'));
    await tester.pump();
    expect(find.text('Kossi'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
