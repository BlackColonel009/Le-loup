import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mordeviel/audio/classic_audio.dart';
import 'package:mordeviel/design/game_theme.dart';
import 'package:mordeviel/social/friend_messages_overlay.dart';
import 'package:mordeviel/social/friend_messages_service.dart';
import 'package:mordeviel/social/private_chat_screen.dart';
import 'package:mordeviel/social/social_api.dart';
import 'package:mordeviel/social/social_notifications.dart';

Map<String, dynamic> notice(int friend, int id, String name, String text) => {
  'friend_id': friend,
  'last_id': id,
  'nickname': name,
  'text': text,
  'unread_count': 2,
  'avatar': null,
};

class MessagesApi extends SocialApi {
  List<Map<String, dynamic>> unread = [
    notice(2, 20, 'Lina', 'On se rejoint au village ?'),
    notice(3, 15, 'Kossi', 'Bonjour !'),
  ];
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? deviceToken,
  }) async {
    if (path == '/social/chats/inbox') {
      return {'viewer_id': 1, 'conversations': List.of(unread)};
    }
    if (path.endsWith('/read')) {
      final id = int.parse(path.split('/')[3]);
      unread.removeWhere(
        (m) =>
            m['friend_id'] == id &&
            (m['last_id'] as int) <= (body!['through_id'] as int),
      );
      return {'notification_ids': [], 'ok': true};
    }
    final id = int.parse(path.split('/').last);
    final entry = unread.where((m) => m['friend_id'] == id).firstOrNull;
    return {
      'viewer_id': 1,
      'friend': {'id': id, 'nickname': entry?['nickname'] ?? 'Ami'},
      'reset_at': null,
      'messages': [
        <String, dynamic>{
          'id': entry?['last_id'] ?? 1,
          'sender_id': id,
          'sender': entry?['nickname'] ?? 'Ami',
          'text': 'Message privé',
          'created': 1793740000,
        },
      ],
    };
  }
}

void main() {
  testWidgets(
    'Aperçu, pile, lecture, fermeture et masquage pendant une partie',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      final original = SocialApi.instance;
      final muted = ClassicAudio.instance.muted;
      ClassicAudio.instance.muted = true;
      final api = MessagesApi();
      SocialApi.instance = api;
      addTearDown(() {
        SocialApi.instance = original;
        ClassicAudio.instance.muted = muted;
      });
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = FriendMessagesService();
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          theme: GameTheme.classic,
          navigatorKey: navigator,
          builder: (_, child) => FriendMessagesOverlay(
            navigatorKey: navigator,
            service: service,
            child: child!,
          ),
          home: const Scaffold(body: Center(child: Text('Village en cours'))),
        ),
      );
      await service.refresh();
      await tester.pump();
      expect(find.text('On se rejoint au village ?'), findsOneWidget);
      expect(find.byKey(const ValueKey('friend-alert-2')), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('On se rejoint au village ?'), findsNothing);
      expect(find.byKey(const ValueKey('friend-alert-2')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('friend-alert-2')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(const ValueKey('friend-alert-2')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.byType(PrivateChatScreen), findsOneWidget);
      expect(find.text('Message privé'), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.text('Village en cours'), findsOneWidget);
      expect(find.byKey(const ValueKey('friend-alert-2')), findsNothing);
      expect(find.byKey(const ValueKey('friend-alert-3')), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('friend-alert-3')),
        const Offset(-85, 0),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(service.alerts, isEmpty);
      await service.refresh();
      expect(service.alerts, isEmpty);
      api.unread = [notice(3, 21, 'Kossi', 'Nouveau message')];
      await service.refresh();
      await tester.pump();
      expect(find.text('Nouveau message'), findsOneWidget);
      pendingSocialNotification.value = 'chat:3';
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      expect(find.byType(PrivateChatScreen), findsOneWidget);
      navigator.currentState!.pop();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      service.dispose();
    },
  );

  test(
    'Les notifications de message utilisent la goutte et un lien de discussion',
    () {
      expect(
        messageSoundDetails('game').sound?.sound,
        'mordeviel_message_drop',
      );
      expect(
        messageSoundDetails('game').channelId,
        'mordeviel_messages_cave_v1',
      );
      expect(messageSoundDetails('phone').sound, isNull);
      expect(
        messageSoundDetails('phone').channelId,
        'mordeviel_messages_phone_v1',
      );
    },
  );
}
