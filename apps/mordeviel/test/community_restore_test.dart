import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mordeviel/community/community_native.dart';
import 'package:mordeviel/community/community_session.dart';
import 'package:mordeviel/services/server_config.dart';
import 'package:mordeviel/social/social_api.dart';
import 'package:local_host/local_host.dart';

class _Headers extends Fake implements HttpHeaders {
  String? token;
  @override
  set contentType(ContentType? value) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    if (name == 'Authorization') token = value.toString();
  }
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.statusCode, this.data);
  @override
  final int statusCode;
  final Map<String, dynamic> data;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(utf8.encode(jsonEncode(data))).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request extends Fake implements HttpClientRequest {
  _Request(this.complete);
  final _Response Function(_Headers) complete;
  @override
  final _Headers headers = _Headers();
  @override
  set followRedirects(bool value) {}
  @override
  void write(Object? value) {}
  @override
  Future<HttpClientResponse> close() async => complete(headers);
}

class _Client extends Fake implements HttpClient {
  final calls = <String>[];
  bool revoked = false;
  bool failMessages = false;
  @override
  set connectionTimeout(Duration? value) {}
  @override
  void close({bool force = false}) {}
  @override
  Future<HttpClientRequest> getUrl(Uri uri) => openUrl('GET', uri);
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _Request((headers) {
        calls.add(url.path);
        if (url.path == '/community/login')
          return _Response(200, {
            'token': 'restored-token',
            'expires_at':
                DateTime.now()
                    .add(const Duration(days: 14))
                    .millisecondsSinceEpoch /
                1000,
            'user': {
              'id': 1,
              'nickname': 'Alice',
              'role': 'player',
              'email_verified': true,
            },
          });
        if (url.path.startsWith('/community/')) {
          expect(headers.token, 'Bearer restored-token');
        }
        if (revoked) return _Response(401, {'detail': 'Session expirée.'});
        if (failMessages && url.path == '/community/messages')
          return _Response(503, {});
        return _Response(200, switch (url.path) {
          '/community/me' => {
            'user': {'nickname': 'Alice', 'role': 'player', 'muted_until': 0},
          },
          '/community/messages' => {'messages': []},
          '/community/tickets' => {'tickets': []},
          _ => {'ok': true, 'items': [], 'content': []},
        });
      });
}

class _SocialFixture extends SocialApi {
  @override
  Future<Map<String,dynamic>> request(String path,{String method='GET',Map<String,dynamic>? body,String? deviceToken}) async => {'ok':true};
}

void main() {
  late SocialApi originalSocial;
  setUp(() {
    originalSocial=SocialApi.instance;
    SocialApi.instance=_SocialFixture();
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(()=>SocialApi.instance=originalSocial);
  final server = onlineServerUri(apiBaseUrl).toString();
  Future<void> seed() => CommunitySessionStore(server).save(
    CommunitySession(
      token: 'restored-token',
      nickname: 'Alice',
      expiresAt: DateTime.now().add(const Duration(days: 12)),
    ),
  );
  testWidgets(
    'Un chargement raté après connexion conserve le compte et réessaie automatiquement',
    (tester) async {
      tester.view.physicalSize = const Size(800,1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await CommunitySessionStore(server).clear();
      final http = _Client()..failMessages = true;
      await HttpOverrides.runZoned(() async {
        await tester.pumpWidget(const MaterialApp(home: CommunityScreen()));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('J’ai déjà un compte'), 150,
          scrollable:find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('J’ai déjà un compte'));
        await tester.pumpAndSettle();
        Finder field(String name) => find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == name,
        );
        await tester.scrollUntilVisible(field('Pseudo ou email'), -150,
          scrollable:find.byType(Scrollable).first);
        await tester.enterText(field('Pseudo ou email'), 'Alice');
        await tester.scrollUntilVisible(field('Mot de passe'), 100,
          scrollable:find.byType(Scrollable).first);
        await tester.enterText(field('Mot de passe'), 'test-password-123');
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        final loginButton = find.widgetWithText(FilledButton,'Me connecter');
        await tester.scrollUntilVisible(loginButton,100,
          scrollable:find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(loginButton);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Mon profil'), findsOneWidget);
        expect(
          find.textContaining('Connexion réussie, mais le chargement'),
          findsOneWidget,
        );
        expect((await CommunitySessionStore(server).load())?.nickname, 'Alice');
        http.failMessages = false;
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Connexion réussie, mais le chargement'),
          findsNothing,
        );
        expect(find.byTooltip('Mon profil'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      }, createHttpClient: (_) => http);
      await CommunitySessionStore(server).clear();
    },
  );

  testWidgets(
    'Quitter et rouvrir la communauté conserve la connexion ; logout la retire',
    (tester) async {
      await seed();
      final http = _Client();
      await HttpOverrides.runZoned(() async {
        await tester.pumpWidget(const MaterialApp(home: CommunityScreen()));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Mon profil'), findsOneWidget);
        expect(find.textContaining('Bienvenue Alice'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await tester.pumpWidget(const MaterialApp(home: CommunityScreen()));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Mon profil'), findsOneWidget);
        expect(
          http.calls.where((path) => path == '/community/me'),
          hasLength(2),
        );
        expect(http.calls, isNot(contains('/community/login')));
        await tester.tap(find.byTooltip('Se déconnecter'));
        await tester.pumpAndSettle();
        expect(find.text('Me connecter'), findsOneWidget);
        expect(await CommunitySessionStore(server).load(), isNull);
        expect(tester.takeException(), isNull);
      }, createHttpClient: (_) => http);
    },
  );

  testWidgets('Une session révoquée côté serveur retourne à la connexion', (
    tester,
  ) async {
    await seed();
    final http = _Client()..revoked = true;
    await HttpOverrides.runZoned(() async {
      await tester.pumpWidget(const MaterialApp(home: CommunityScreen()));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Mon profil'), findsNothing);
      expect(find.text('Me connecter'), findsOneWidget);
      expect(await CommunitySessionStore(server).load(), isNull);
      expect(tester.takeException(), isNull);
    }, createHttpClient: (_) => http);
  });
}
