import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/audio/classic_audio.dart';
import 'package:mordeviel/social/friend_messages_overlay.dart';
import 'package:mordeviel/social/friend_messages_service.dart';
import 'package:mordeviel/social/social_api.dart';
import 'package:mordeviel/community/community_conversation.dart';

class CommunityAlertsApi extends SocialApi {
  final paths = <String>[];
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? deviceToken,
  }) async {
    paths.add(path);
    return path == '/social/chats/inbox'
        ? {'viewer_id': 1, 'conversations': []}
        : {
            'messages': [
              {
                'id': 1,
                'user_id': 2,
                'nickname': 'Lina',
                'text': 'Ancien message',
              },
            ],
          };
  }
}

void main() {
  testWidgets(
    'Community is read only while its discussion tab and route are visible',
    (tester) async {
      final previousApi = SocialApi.instance;
      SocialApi.instance = CommunityAlertsApi();
      final service = FriendMessagesService.instance;
      service.clear();
      final text = TextEditingController();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          home: DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                bottom: const TabBar(
                  tabs: [
                    Tab(text: 'Discussion'),
                    Tab(text: 'Support'),
                  ],
                ),
              ),
              body: TabBarView(
                children: [
                  CommunityConversation(
                    messages: const [],
                    controller: text,
                    onSend: () {},
                    onSticker: () {},
                    onProfile: (_) {},
                    onReport: (_) {},
                  ),
                  const Center(child: Text('Support privé')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.activeFriend, -1);
      await tester.tap(find.text('Support'));
      await tester.pumpAndSettle();
      expect(service.activeFriend, isNull);
      await tester.tap(find.text('Discussion'));
      await tester.pumpAndSettle();
      expect(service.activeFriend, -1);
      navigator.currentState!.push<void>(
        MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Profil'))),
      );
      await tester.pumpAndSettle();
      expect(service.activeFriend, isNull);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(service.activeFriend, -1);
      await tester.pumpWidget(const SizedBox());
      await service.refresh();
      service.clear();
      text.dispose();
      SocialApi.instance = previousApi;
    },
  );

  testWidgets(
    'Community preview expires, bubble stays and new messages restore it',
    (tester) async {
      final previousApi = SocialApi.instance;
      final muted = ClassicAudio.instance.muted;
      final api = CommunityAlertsApi();
      SocialApi.instance = api;
      ClassicAudio.instance.muted = true;
      addTearDown(() {
        SocialApi.instance = previousApi;
        ClassicAudio.instance.muted = muted;
      });
      final service = FriendMessagesService();
      await service.refresh();
      expect(service.alerts, isEmpty);
      await service.refresh();
      expect(api.paths, contains('/community/messages?after=1'));
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          builder: (_, child) => FriendMessagesOverlay(
            navigatorKey: navigator,
            service: service,
            child: child!,
          ),
          home: const Scaffold(body: Text('Partie en cours')),
        ),
      );
      service.acceptCommunity([
        {'id': 2, 'user_id': 1, 'nickname': 'Moi', 'text': 'Mon message'},
      ]);
      expect(service.alerts, isEmpty);
      service.acceptCommunity([
        {
          'id': 3,
          'user_id': 2,
          'nickname': 'Lina',
          'text': 'Bonjour le village',
        },
      ]);
      await tester.pump();
      expect(find.text('Lina : Bonjour le village'), findsOneWidget);
      expect(find.text('Communauté'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(find.text('Lina : Bonjour le village'), findsNothing);
      expect(find.byKey(const ValueKey('friend-alert--1')), findsOneWidget);
      expect(find.text('Partie en cours'), findsOneWidget);
      service.accept([]);
      expect(service.preview, isNull);
      expect(service.alerts, hasLength(1));
      service.dismiss(-1);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('friend-alert--1')), findsNothing);
      service.acceptCommunity([
        {'id': 4, 'user_id': 3, 'nickname': 'Kossi', 'text': 'Bonsoir'},
      ]);
      await tester.pump();
      expect(find.text('Kossi : Bonsoir'), findsOneWidget);
      service.reading(-1);
      await tester.pump();
      expect(service.alerts, isEmpty);
      service.acceptCommunity([
        {'id': 5, 'user_id': 2, 'nickname': 'Lina', 'text': 'Déjà affiché'},
      ]);
      expect(service.alerts, isEmpty);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    },
  );
}
