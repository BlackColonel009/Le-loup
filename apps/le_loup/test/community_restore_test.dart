import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:le_loup/community/community_native.dart';
import 'package:le_loup/community/community_session.dart';
import 'package:le_loup/services/server_config.dart';
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
  void write(Object? value) {}
  @override
  Future<HttpClientResponse> close() async => complete(headers);
}

class _Client extends Fake implements HttpClient {
  final calls = <String>[];
  bool revoked = false;
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
        if (url.path.startsWith('/community/')) {
          expect(headers.token, 'Bearer restored-token');
        }
        if (revoked) return _Response(401, {'detail': 'Session expirée.'});
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

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  final server = onlineServerUri(apiBaseUrl).toString();
  Future<void> seed() => CommunitySessionStore(server).save(
    CommunitySession(
      token: 'restored-token',
      nickname: 'Alice',
      expiresAt: DateTime.now().add(const Duration(hours: 20)),
    ),
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
