import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_host/local_host.dart';
import 'package:mordeviel/social/private_chat_screen.dart';
import 'package:mordeviel/social/social_api.dart';
import 'package:mordeviel/community/community_conversation.dart';
import 'package:mordeviel/stickers/sticker_keywords.dart';
import 'package:mordeviel/stickers/sticker_suggestions.dart';
import 'chat_reply_test.dart' show ChatApi;

void main() {
  testWidgets(
    'Communauté compacte avec onglets et clavier : les suggestions ne ferment pas la saisie',
    (tester) async {
      final old = SocialApi.instance;
      SocialApi.instance = ChatApi();
      addTearDown(() => SocialApi.instance = old);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final text = TextEditingController();
      addTearDown(text.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Communauté'),
                bottom: const TabBar(
                  tabs: [
                    Tab(text: 'Discussion'),
                    Tab(text: 'Profil'),
                  ],
                ),
              ),
              body: CommunityConversation(
                messages: const [],
                controller: text,
                reply: const {'nickname': 'Luna', 'text': 'On joue ce soir ?'},
                onCancelReply: () {},
                onSend: () {},
                onSticker: () {},
                onSuggestedSticker: (_) {},
                onProfile: (_) {},
                onReport: (_) {},
              ),
            ),
          ),
        ),
      );
      final input = find.byKey(const ValueKey('community-chat-input'));
      await tester.enterText(input, 'bonjour');
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.widget<TextField>(input).focusNode!.hasFocus, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'Accents, phrases et préfixes déclenchent les bons stickers sans sous-mots',
    () {
      List<String> ids(String draft) =>
          suggestStickers(draft).map((s) => s.id).toList();
      expect(ids('Bonjour !'), contains('classic_villager_joy'));
      expect(ids('J’ai PEUR'), contains('classic_scapegoat_scared'));
      expect(ids('je vote'), contains('classic_mayor_confident'));
      expect(ids('une pot'), contains('classic_witch_determined'));
      expect(ids('un loup'), contains('classic_werewolf_angry'));
      expect(ids('soupçonné'), isNot(contains('classic_mayor_confident')));
      expect(ids(''), isEmpty);
      expect(ids('[[sticker:classic_villager_joy]]'), isEmpty);
      expect(suggestStickers('loup', limit: 2), hasLength(2));
    },
  );
  testWidgets(
    'Les suggestions ne changent ni le brouillon ni le focus et cachent les récompenses verrouillées',
    (tester) async {
      final old = SocialApi.instance;
      SocialApi.instance = ChatApi();
      addTearDown(() => SocialApi.instance = old);
      final text = TextEditingController();
      final focus = FocusNode();
      addTearDown(text.dispose);
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StickerSuggestions(controller: text, onSelect: (_) {}),
                TextField(controller: text, focusNode: focus),
              ],
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'bonjour');
      await tester.pump();
      expect(
        find.byKey(const ValueKey('suggest-classic_villager_joy')),
        findsOneWidget,
      );
      expect(focus.hasFocus, isTrue);
      expect(text.text, 'bonjour');
      text.text = 'loup';
      await tester.pump();
      for (final sticker in chatStickers.where((s) => s.pack == 'rewards')) {
        expect(find.byKey(ValueKey('suggest-${sticker.id}')), findsNothing);
      }
      text.clear();
      await tester.pump();
      expect(find.byKey(const ValueKey('sticker-suggestions')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Petit téléphone avec clavier : réponse et suggestions gardent la saisie accessible',
    (tester) async {
      final old = SocialApi.instance;
      SocialApi.instance = ChatApi();
      addTearDown(() => SocialApi.instance = old);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        const MaterialApp(
          home: PrivateChatScreen(friendId: 2, nickname: 'Luna'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.text('On joue ce soir ?'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'bonjour');
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const ValueKey('sticker-suggestions')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
