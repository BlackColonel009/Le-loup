import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_host/local_host.dart';
import 'package:mordeviel/chat/message_reply.dart';
import 'package:mordeviel/community/community_conversation.dart';
import 'package:mordeviel/social/private_chat_screen.dart';
import 'package:mordeviel/social/social_api.dart';
import 'package:mordeviel/village/village_chat.dart';
import 'package:mordeviel/stickers/chat_stickers.dart';

class ChatApi extends SocialApi {
  Map<String, dynamic>? sent;
  final messages = <Map<String, dynamic>>[
    {'id': 1, 'sender_id': 2, 'text': 'On joue ce soir ?'},
  ];
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? deviceToken,
  }) async {
    if (path == '/collection/me') return {'products': <Map>[]};
    if (method == 'POST') {
      sent = body;
      messages.add({
        'id': 2,
        'sender_id': 1,
        'text': body!['text'],
        'reply': {'id': 1, 'sender': 'Luna', 'text': messages.first['text']},
      });
      return {'ok': true};
    }
    return {'messages': List.of(messages), 'viewer_id': 1, 'reset_at': null};
  }
}

void main() {
  test('Références stables et citations privées limitées à leur canal', () {
    var now = DateTime.utc(2026, 11, 3);
    final game = NightGame({
      'w': 'werewolf',
      'x': 'werewolf',
      'a': 'villager',
      'b': 'villager',
      'c': 'villager',
    }, clock: () => now);
    void send(String who, String action, String text, [String? reply]) =>
        game.act(who, {
          'action': action,
          'phase_revision': game.revision,
          'text': text,
          'reply_to': ?reply,
        });
    game.startNight();
    game.callNight('wolves');
    send('w', 'wolves.chat', 'La meute hésite');
    final original = (game.privateState('w')['messages'] as List).single as Map;
    send('x', 'wolves.chat', 'Je suis ton choix', original['id']);
    final reply = (game.privateState('w')['messages'] as List).last as Map;
    expect(reply['reply_author'], 'w');
    expect(reply['reply_text'], 'La meute hésite');
    expect(game.privateState('a').containsKey('messages'), isFalse);
    game.advance();
    game.finishNight();
    game.advance();
    expect(game.phase, 'day');
    expect(
      () => send('a', 'day.chat', 'Citation de meute', original['id']),
      throwsArgumentError,
    );
    send('a', 'day.chat', '[[sticker:classic_villager_joy]]');
    final day = (game.publicState['day_messages'] as List).single as Map;
    send('b', 'day.chat', 'Belle émotion', day['id']);
    expect(
      (game.publicState['day_messages'] as List).last['reply_text'],
      '[[sticker:classic_villager_joy]]',
    );
    now = now.add(const Duration(seconds: 2));
    send('a', 'day.chat', 'Encore');
    expect(
      (game.publicState['day_messages'] as List).map((m) => m['id']).toSet(),
      hasLength(3),
    );
  });

  testWidgets(
    'Discussion privée : appui long, saisie liée puis citation persistante',
    (tester) async {
      final old = SocialApi.instance;
      final api = ChatApi();
      SocialApi.instance = api;
      addTearDown(() => SocialApi.instance = old);
      await tester.pumpWidget(
        const MaterialApp(
          home: PrivateChatScreen(friendId: 2, nickname: 'Luna'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.text('On joue ce soir ?'));
      await tester.pump();
      expect(find.byKey(const ValueKey('reply-composer')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('private-chat-input')),
        'Oui, ce soir',
      );
      await tester.tap(find.byTooltip('Envoyer'));
      await tester.pumpAndSettle();
      expect(api.sent, {'text': 'Oui, ce soir', 'reply_to': 1});
      expect(find.byKey(const ValueKey('reply-composer')), findsNothing);
      expect(find.byKey(const ValueKey('message-quotation')), findsOneWidget);
      expect(find.text('Oui, ce soir'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Communauté : sélectionner et annuler sans perdre le brouillon ni le focus',
    (tester) async {
      final text = TextEditingController(text: 'Mon brouillon');
      addTearDown(text.dispose);
      Map<String, dynamic>? reply;
      late StateSetter update;
      final message = <String, dynamic>{
        'id': 7,
        'user_id': 2,
        'nickname': 'Luna',
        'role': 'player',
        'created': 0,
        'text': 'Bonsoir au village',
      };
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, set) {
                update = set;
                return CommunityConversation(
                  messages: [message],
                  controller: text,
                  onSend: () {},
                  onSticker: () {},
                  onProfile: (_) {},
                  onReport: (_) {},
                  reply: reply,
                  onReply: (m) => update(() => reply = m),
                  onCancelReply: () => update(() => reply = null),
                );
              },
            ),
          ),
        ),
      );
      await tester.longPress(find.text('Bonsoir au village'));
      await tester.pump();
      expect(find.text('Réponse à Luna'), findsOneWidget);
      final input = find.byKey(const ValueKey('community-chat-input'));
      final focus = tester.widget<TextField>(input).focusNode;
      expect(focus!.hasFocus, isTrue);
      await tester.tap(find.byTooltip('Annuler la réponse'));
      await tester.pump();
      expect(text.text, 'Mon brouillon');
      expect(tester.widget<TextField>(input).focusNode, same(focus));
      expect(find.byKey(const ValueKey('reply-composer')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Conseil : la réponse est transmise puis effacée lors du changement de canal',
    (tester) async {
      Map<String, dynamic> game = {
        'phase': 'day',
        'night': 1,
        'phase_revision': 2,
        'chat_open': true,
        'day_messages': [
          {'id': 'message-1', 'author': 'b', 'text': 'Qui est suspect ?'},
        ],
      };
      String? ref;
      Widget scene() => MaterialApp(
        home: Scaffold(
          body: VillageChat(
            room: {
              'phase': game['phase'],
              'game': game,
              'players': [
                {'id': 'a', 'nickname': 'A'},
                {'id': 'b', 'nickname': 'B'},
              ],
            },
            privateState: const {'alive': true, 'id': 'a'},
            connected: true,
            isHost: false,
            onSend: (action, revision, text, {replyTo}) => ref = replyTo,
          ),
        ),
      );
      await tester.pumpWidget(scene());
      final focus = tester.widget<TextField>(find.byType(TextField)).focusNode;
      await tester.longPress(find.text('Qui est suspect ?'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).focusNode,
        same(focus),
      );
      expect(focus!.hasFocus, isTrue);
      expect(find.byType(MessageReply), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Je réfléchis');
      await tester.pump();
      await tester.tap(find.text('Envoyer'));
      expect(ref, 'message-1');
      await tester.pump();
      expect(find.byType(MessageReply), findsNothing);
      game = {'phase': 'sleep', 'phase_revision': 3};
      await tester.pumpWidget(scene());
      expect(find.byKey(const ValueKey('reply-composer')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Les accessoires du nouveau pack sont verrouillés sans acquisition',
    (tester) async {
      final old = SocialApi.instance;
      SocialApi.instance = ChatApi();
      addTearDown(() => SocialApi.instance = old);
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: StickerPicker())),
      );
      await tester.pump();
      await tester.tap(find.text('À collectionner'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(chatStickers.where((s) => s.pack == 'rewards'), hasLength(58));
      await tester.tap(
        find.byKey(const ValueKey('pick-rewards_villager_suspect')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Sticker à débloquer'), findsOneWidget);
      expect(find.text('Voir les accessoires'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
