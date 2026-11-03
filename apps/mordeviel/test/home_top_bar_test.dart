import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mordeviel/community/community_session.dart';
import 'package:mordeviel/design/home_top_bar.dart';
import 'package:mordeviel/profile/player_avatar.dart';
import 'package:mordeviel/profile/avatar_border.dart';
import 'package:mordeviel/social/social_api.dart';
import 'package:mordeviel/social/social_service.dart';

class _HomeApi extends SocialApi {
  var border = 'creator-gold';
  var signed = true;
  @override
  Future<CommunitySession?> session() async => signed
      ? CommunitySession(
          token: 'test',
          nickname: 'Logan R.D',
          expiresAt: DateTime.now().add(const Duration(days: 1)),
        )
      : null;
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? deviceToken,
  }) async {
    if (!signed) throw const SocialError(401, 'Reconnectez-vous');
    if (path == '/social/summary') {
      return {
        'user_id': 1,
        'nickname': 'Logan R.D',
        'avatar': {
          'id': 'creator-wolf',
          'kind': 'game',
          'pack_id': 'avatars-classic',
          'border_id': border,
          'is_creator': true,
        },
        'friend_requests': 2,
        'invitations': 1,
        'challenge_rewards': 3,
        'phone_notifications': false,
      };
    }
    return {'alerts': []};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory support;
  late SocialApi original;
  late _HomeApi api;
  setUpAll(() async {
    support = await Directory.systemTemp.createTemp('wolf-topbar-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => support.path,
        );
  });
  tearDownAll(() async => support.delete(recursive: true));
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    original = SocialApi.instance;
    api = _HomeApi();
    SocialApi.instance = api;
  });
  tearDown(() {
    SocialApi.instance = original;
    debugDefaultTargetPlatformOverride = null;
  });
  testWidgets('Le profil équipé, ses effets et le menu s’adaptent à l’écran', (
    tester,
  ) async {
    const size = Size(320, 568);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(appBar: HomeTopBar())),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Logan R.D'), findsOneWidget);
    final portrait = tester.widget<PlayerAvatar>(
      find.byKey(const ValueKey('home-equipped-avatar')),
    );
    expect(portrait.avatar?['id'], 'creator-wolf');
    expect(portrait.avatar?['is_creator'], true);
    expect(
      tester
          .widget<AnimatedAvatarBorder>(find.byType(AnimatedAvatarBorder))
          .border['id'],
      'creator-gold',
    );
    final news = find.descendant(
      of: find.byKey(const ValueKey('home-menu-news')),
      matching: find.byType(Badge),
    );
    expect(
      tester.widget<Badge>(news).label,
      isA<Text>().having((t) => t.data, 'count', '6'),
    );
    expect(find.byTooltip('Communauté'), findsOneWidget);
    expect(find.byTooltip('Ambiance sonore'), findsOneWidget);
    expect(
      find.byTooltip('Mes téléchargements · 1 pack(s) à compléter'),
      findsOneWidget,
    );
    expect(find.text('Boutique'), findsNothing);
    final profile = tester.getRect(find.byKey(const ValueKey('home-profile')));
    final menu = tester.getRect(find.byKey(const ValueKey('home-menu')));
    expect(menu.left - profile.right, lessThan(12));
    await tester.tap(find.byKey(const ValueKey('home-menu')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Boutique'), findsOneWidget);
    expect(find.text('Mon cercle'), findsOneWidget);
    expect(find.text('Invitations'), findsOneWidget);
    expect(find.text('Défis'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tapAt(Offset(10, size.height - 8));
    await tester.pump(const Duration(milliseconds: 300));
    tester.view.physicalSize = const Size(1024, 600);
    await tester.pump();
    expect(
      tester.getRect(find.byKey(const ValueKey('home-menu'))).left -
          tester.getRect(find.byKey(const ValueKey('home-profile'))).right,
      lessThan(12),
    );
    api.border = 'ruby';
    await SocialService.instance.refresh(afterCurrent: true);
    await tester.pump();
    expect(
      tester
          .widget<AnimatedAvatarBorder>(find.byType(AnimatedAvatarBorder))
          .border['id'],
      'ruby',
    );
    api.signed = false;
    await SocialService.instance.refresh(afterCurrent: true);
    await tester.pump();
    expect(find.text('Logan R.D'), findsNothing);
    expect(find.text('Mon profil'), findsOneWidget);
    expect(tester.widget<Badge>(news).isLabelVisible, false);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });
}
