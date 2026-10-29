import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_host/local_host.dart';
import 'package:mordeviel/village/village_chat.dart';
import 'package:mordeviel/village/horror_ambience.dart';
import 'package:mordeviel/village/village_map.dart';
import 'package:mordeviel/village/guardian_aura.dart';
import 'package:mordeviel/social/social_api.dart';
import 'package:mordeviel/social/private_chat_screen.dart';
import 'package:mordeviel/village/revival_scene.dart';
import 'package:mordeviel/cards/card_gallery.dart';

class FriendChatApi extends SocialApi {
  final messages = <Map<String, dynamic>>[];
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? deviceToken,
  }) async {
    if (method == 'POST') {
      messages.add({'sender_id': 1, 'text': body!['text']});
      return {'ok': true};
    }
    return {
      'messages': List.of(messages),
      'viewer_id': 1,
      'reset_at': DateTime.now().millisecondsSinceEpoch / 1000 + 86400,
    };
  }
}

void main() {
  testWidgets('La seconde chance affiche le message et se ferme proprement', (
    tester,
  ) async {
    var revealed = 0;
    var closed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showRevival(
                context,
                role: 'seer',
                ambience: CardAmbience.classic,
                rescuer: 'Morgane',
                onReveal: () => revealed++,
                onClose: () => closed++,
              ),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text(revivalText), findsOneWidget);
    expect(find.textContaining('Morgane'), findsOneWidget);
    expect(revealed, 1);
    await tester.ensureVisible(find.text('Choisir mon destin'));
    await tester.tap(find.text('Choisir mon destin'));
    await tester.pumpAndSettle();
    expect(closed, 1);
    expect(tester.takeException(), isNull);
  });
  test('Passages des chauves-souris : jour et nuit avec des pauses', () {
    expect(horrorBatProgress(15, night: true), inExclusiveRange(0, 1));
    expect(horrorBatProgress(44, night: false), inExclusiveRange(0, 1));
    expect(horrorBatProgress(30, night: false), -1);
  });
  testWidgets(
    'Une discussion privée envoie un message et conserve son champ de saisie',
    (tester) async {
      final previous = SocialApi.instance;
      final api = FriendChatApi();
      SocialApi.instance = api;
      addTearDown(() => SocialApi.instance = previous);
      await tester.pumpWidget(
        const MaterialApp(
          home: PrivateChatScreen(friendId: 2, nickname: 'Bob'),
        ),
      );
      await tester.pumpAndSettle();
      final input = find.byKey(const ValueKey('private-chat-input'));
      expect(find.byTooltip('Stickers'), findsOneWidget);
      await tester.enterText(input, 'Salut mon ami');
      await tester.tap(find.byTooltip('Envoyer'));
      await tester.pumpAndSettle();
      expect(find.text('Salut mon ami'), findsOneWidget);
      expect(tester.widget<TextField>(input).controller!.text, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final theme in ['classic', 'intense', 'horror']) {
    testWidgets(
      'Protection appliquée uniquement à la maison choisie · $theme',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(disableAnimations: true),
              child: Scaffold(
                body: VillageMap(
                  room: {
                    'visual_pack': theme,
                    'phase': 'guardian',
                    'players': [
                      {
                        'id': 'a',
                        'nickname': 'Alice',
                        'house_slot': 0,
                        'connected': true,
                      },
                      {
                        'id': 'b',
                        'nickname': 'Bob',
                        'house_slot': 1,
                        'connected': true,
                      },
                    ],
                    'game': {
                      'is_night': true,
                      'alive_ids': ['a', 'b'],
                    },
                  },
                  protectedPlayerId: 'b',
                  animateGhosts: false,
                  onHouse: (_) {},
                  onChat: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('a')),
            matching: find.byType(GuardianAura),
          ),
          findsNothing,
        );
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('b')),
            matching: find.byType(GuardianAura),
          ),
          findsOneWidget,
        );
        expect(
          tester.widget<GuardianAura>(find.byType(GuardianAura)).intense,
          theme != 'classic',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final reveal in [false, true]) {
    test(
      'Potion de vie : notification privée, identité de la Sorcière optionnelle ($reveal)',
      () {
        final g = NightGame({
          'w': 'werewolf',
          's': 'witch',
          'v': 'villager',
          'a': 'villager',
        }, revealRescuer: reveal);
        g.startNight();
        g.callNight('wolves');
        g.act('w', {
          'action': 'wolves.choose',
          'phase_revision': g.revision,
          'target': 'v',
        });
        g.advance();
        g.callNight('witch');
        g.act('s', {
          'action': 'witch.potions',
          'phase_revision': g.revision,
          'save': true,
          'kill': null,
        });
        expect(g.privateState('v')['rescues'], isEmpty);
        g.advance();
        g.finishNight();
        final rescued = (g.privateState('v')['rescues'] as List).single as Map;
        expect(rescued.containsKey('rescuer'), reveal);
        if (reveal) expect(rescued['rescuer'], 's');
        expect(g.privateState('w')['rescues'], isEmpty);
        expect(g.privateState('a')['rescues'], isEmpty);
        expect(g.publicState.containsKey('rescues'), isFalse);
      },
    );
  }
  testWidgets(
    'Le champ du conseil conserve focus et brouillon lors de l’ouverture du clavier',
    (tester) async {
      var height = 600.0;
      final room = <String, dynamic>{
        'phase': 'day',
        'players': <Map<String, dynamic>>[],
        'game': {'phase_revision': 1, 'chat_open': true},
      };
      Widget scene() => MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: height,
              child: VillageChat(
                room: room,
                privateState: const {'alive': true},
                isHost: false,
                connected: true,
                onSend: (_, _, _) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(scene());
      final field = find.byKey(const ValueKey('village-chat-input'));
      await tester.tap(field);
      await tester.enterText(field, 'Mon soupçon…');
      await tester.pump();
      final oldState = tester.state(field);
      height = 290;
      await tester.pumpWidget(scene());
      await tester.pump();
      expect(identical(tester.state(field), oldState), isTrue);
      final widget = tester.widget<TextField>(field);
      expect(widget.focusNode!.hasFocus, isTrue);
      expect(widget.controller!.text, 'Mon soupçon…');
      expect(tester.takeException(), isNull);
    },
  );
}
