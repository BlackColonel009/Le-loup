import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mordeviel/community/community_session.dart';
import 'package:mordeviel/design/game_theme.dart';
import 'package:mordeviel/social/online_hub.dart';
import 'package:mordeviel/social/social_api.dart';
import 'package:mordeviel/social/social_screens.dart';

class FakeSocialApi extends SocialApi {
  String visibility = 'public',
      inviteStatus = 'active',
      friendStatus = 'pending';
  final actions = <String>[];
  bool privateVisitor = true;
  Map<String, dynamic> get preferences => {
    'stats_visibility': visibility,
    'invite_emails': true,
    'phone_notifications': false,
    'auto_invite': true,
  };
  Map<String, dynamic> get stats => {
    'games': 12,
    'wins': 7,
    'wolf_victims': 9,
    'devoured': 3,
    'executed': 2,
  };
  Map<String, dynamic> get room => {
    'code': '123456',
    'room_id': 'room-one',
    'title': 'Les veilleurs de minuit',
    'host': 'Logan',
    'owner_id': 1,
    'theme': 'mixed',
    'environment': 'classic',
    'players': 5,
    'capacity': 20,
    'phase': 'lobby',
    'joinable': true,
    'public': true,
  };
  @override
  Future<CommunitySession?> session() async => CommunitySession(
    token: 'test-only',
    nickname: 'Alice',
    expiresAt: DateTime.now().add(const Duration(hours: 1)),
  );
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? deviceToken,
  }) async {
    if (path == '/social/summary')
      return {
        'user_id': 1,
        'nickname': 'Alice',
        'friend_requests': friendStatus == 'pending' ? 1 : 0,
        'invitations': inviteStatus == 'active' ? 1 : 0,
        'phone_notifications': false,
      };
    if (path == '/social/rooms')
      return {
        'rooms': [
          room,
          {
            ...room,
            'code': '654321',
            'title': 'Le hameau des brumes',
            'theme': 'horror',
            'phase': 'wolves',
            'joinable': false,
          },
        ],
      };
    if (path == '/social/me')
      return {
        'id': 1,
        'nickname': 'Alice',
        'is_self': true,
        'verified': false,
        'stats_visible': true,
        'stats': stats,
        'preferences': preferences,
      };
    if (path == '/social/profiles/2')
      return {
        'id': 2,
        'nickname': 'Le Veilleur',
        'is_self': false,
        'verified': false,
        'stats_visible': !privateVisitor,
        if (!privateVisitor) 'stats': stats,
        'is_friend': false,
        'blocked_by_me': false,
        'relationship': actions.contains('request') ? 'pending' : 'none',
        'request_incoming': false,
      };
    if (path == '/social/preferences') {
      visibility = body!['stats_visibility'] as String;
      actions.add('preferences');
      return {'ok': true};
    }
    if (path == '/social/friends')
      return {
        'friends': [
          {
            'id': 2,
            'nickname': 'Le Veilleur',
            'status': friendStatus,
            'incoming': true,
            'online': false,
          },
        ],
      };
    if (path == '/social/recent')
      return {
        'players': [
          {
            'id': 2,
            'nickname': 'Le Veilleur',
            'played_at': 1793185200,
            'games': 3,
            'is_friend': friendStatus == 'accepted',
          },
        ],
      };
    if (path == '/social/invitations')
      return {
        'invitations': [
          {
            'id': 8,
            'nickname': 'Logan',
            'status': inviteStatus,
            'seen': 0,
            'created': 1793185200,
            'expires': 1793192400,
            if (inviteStatus == 'active') 'room': room,
          },
        ],
      };
    if (path == '/social/invitations/8/decline') {
      inviteStatus = 'declined';
      actions.add('decline-invite');
      return {'ok': true};
    }
    if (path == '/social/friends/2') {
      actions.add(body!['action'] as String);
      if (body['action'] == 'accept') friendStatus = 'accepted';
      return {'ok': true};
    }
    throw StateError('Unexpected test endpoint $path');
  }
}

void main() {
  late SocialApi original;
  late FakeSocialApi api;
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_SOCIAL')) {
      await (FontLoader(
        'VillageSans',
      )..addFont(rootBundle.load('assets/fonts/SourceSans3[wght].ttf'))).load();
      final bytes = await File('C:/Windows/Fonts/arial.ttf').readAsBytes();
      await (FontLoader(
        'SocialPreview',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    original = SocialApi.instance;
    api = FakeSocialApi();
    SocialApi.instance = api;
  });
  tearDown(() => SocialApi.instance = original);
  Widget app(Widget child) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: GameTheme.classic.copyWith(
      textTheme: GameTheme.classic.textTheme.apply(
        fontFamily: const bool.fromEnvironment('CAPTURE_SOCIAL')
            ? 'SocialPreview'
            : null,
      ),
    ),
    home: child,
  );
  for (final size in [const Size(360, 740), const Size(900, 420)]) {
    testWidgets(
      'Les salons montrent thème et disponibilité sans débordement à $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(app(const OnlineHubScreen()));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Le hameau des brumes'), 250);
        expect(find.text('Le hameau des brumes'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.widgetWithText(ChoiceChip, 'Mixte'),
          -250,
        );
        await tester.tap(find.widgetWithText(ChoiceChip, 'Mixte'));
        await tester.pumpAndSettle();
        expect(find.text('Les veilleurs de minuit'), findsOneWidget);
        expect(find.text('Le hameau des brumes'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'Le carnet privé masque les statistiques et propose une demande',
    (tester) async {
      await tester.pumpWidget(app(const SocialProfileScreen(userId: 2)));
      await tester.pumpAndSettle();
      expect(find.text('Ce carnet est réservé aux amis.'), findsOneWidget);
      expect(find.text('Victimes en loup'), findsNothing);
      await tester.tap(find.text('Ajouter à mes amis'));
      await tester.pumpAndSettle();
      expect(api.actions, contains('request'));
      expect(find.text('Annuler ma demande'), findsOneWidget);
    },
  );
  testWidgets(
    'Une invitation refusée reste dans l’historique sans accès au salon',
    (tester) async {
      await tester.pumpWidget(app(const SocialHubScreen(initialTab: 2)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Décliner l’invitation'));
      await tester.pumpAndSettle();
      expect(api.actions, contains('decline-invite'));
      expect(find.textContaining('Invitation refusée'), findsOneWidget);
      expect(find.text('Rejoindre le salon'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Le propriétaire peut réserver ses statistiques aux amis', (
    tester,
  ) async {
    await tester.pumpWidget(app(const SocialProfileScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Victimes en loup'), findsOneWidget);
    final dropdown = find.byType(DropdownButtonFormField<String>);
    await tester.scrollUntilVisible(dropdown, 250);
    await tester.pumpAndSettle();
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mes amis uniquement').last);
    await tester.pumpAndSettle();
    expect(api.visibility, 'friends');
    expect(api.actions, contains('preferences'));
  });
  testWidgets('Accepter une demande met à jour la relation', (tester) async {
    await tester.pumpWidget(app(const SocialHubScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Accepter'));
    await tester.pumpAndSettle();
    expect(api.friendStatus, 'accepted');
    expect(find.text('Ami du village'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Aperçu du carnet et des salons dans un téléphone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    for (final entry in [
      ('online', const OnlineHubScreen()),
      ('profile', const SocialProfileScreen()),
      ('invites', const SocialHubScreen(initialTab: 2)),
    ]) {
      await tester.pumpWidget(
        RepaintBoundary(key: boundary, child: app(entry.$2)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_SOCIAL')) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '../../.tmp/social-${entry.$1}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }
  });
}
