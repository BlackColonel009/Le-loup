import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mordeviel/community/community_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'Une session chiffrée se retrouve sans renouveler ses 14 jours',
    () async {
      const server = 'https://session.example';
      final deadline = DateTime.now().add(const Duration(days: 14));
      final first = CommunitySessionStore(server);
      await first.save(
        CommunitySession(
          token: 'private-session',
          nickname: 'Alice',
          expiresAt: deadline,
        ),
      );
      final reopened = await CommunitySessionStore(server).load();
      expect(reopened?.token, 'private-session');
      expect(
        reopened?.expiresAt.millisecondsSinceEpoch,
        deadline.millisecondsSinceEpoch,
      );
      final later = await first.load(
        now: deadline.subtract(const Duration(days: 3)),
      );
      expect(
        later?.expiresAt.millisecondsSinceEpoch,
        deadline.millisecondsSinceEpoch,
      );
      final persisted = await const FlutterSecureStorage().read(
        key: 'community_session_v1:$server',
      );
      expect(
        jsonDecode(persisted!).keys,
        unorderedEquals(['token', 'nickname', 'expires_at']),
      );
      expect(
        await CommunitySessionStore('https://another.example').load(),
        isNull,
      );
      expect(await first.load(now: deadline), isNull);
      expect(
        await const FlutterSecureStorage().read(
          key: 'community_session_v1:$server',
        ),
        isNull,
      );
    },
  );

  test(
    'Reprise depuis le stockage après un redémarrage puis déconnexion',
    () async {
      const server = 'https://restart.example';
      final deadline = DateTime.now().add(const Duration(days: 12));
      FlutterSecureStorage.setMockInitialValues({
        'community_session_v1:$server': jsonEncode({
          'token': 'persisted-token',
          'nickname': 'Logan',
          'expires_at': deadline.millisecondsSinceEpoch,
        }),
      });
      final store = CommunitySessionStore(server);
      expect((await store.load())?.nickname, 'Logan');
      await store.clear();
      expect(await CommunitySessionStore(server).load(), isNull);
    },
  );

  test(
    'Une sauvegarde suivie de la déconnexion ne ressuscite pas le jeton',
    () async {
      final store = CommunitySessionStore('https://logout.example');
      final save = store.save(
        CommunitySession(
          token: 'old-token',
          nickname: 'Alice',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      final clear = store.clear();
      await Future.wait([save, clear]);
      expect(await store.load(), isNull);
    },
  );
  test('Une échéance dépassant 14 jours reste refusée', () async {
    final store = CommunitySessionStore('https://invalid-duration.example');
    await store.save(
      CommunitySession(
        token: 'invalid-deadline',
        nickname: 'Alice',
        expiresAt: DateTime.now().add(const Duration(days: 15)),
      ),
    );
    expect(await store.load(), isNull);
  });
}
