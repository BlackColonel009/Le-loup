import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mordeviel/services/app_updates.dart';
import 'package:mordeviel/services/app_update_gate.dart';

Map<String, dynamic> manifest({
  String version = '0.2.0+2',
  String? id,
  String url = 'https://mega.nz/file/apk#public-key',
}) => {
  'enabled': true,
  'platform': 'android',
  'version': version,
  'download_url': url,
  'release_id': id ?? List.filled(64, 'a').join(),
};
PackageInfo installed(String version, String build, int stamp) => PackageInfo(
  appName: 'Mordeviel',
  packageName: 'com.mordeviel.mordeviel',
  version: version,
  buildNumber: build,
  updateTime: DateTime.fromMillisecondsSinceEpoch(stamp),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  test('La version et le numéro de build sont comparés numériquement', () {
    expect(compareAppVersions('0.10.0', '0.9.0', '1'), greaterThan(0));
    expect(compareAppVersions('0.2.0+3', '0.2.0', '2'), greaterThan(0));
    expect(compareAppVersions('0.1.0', '0.2.0', '2'), lessThan(0));
    expect(compareAppVersions('0.2.0', '0.2.0', '2'), 0);
    expect(compareAppVersions('prochainement', '0.2.0', '2'), isNull);
  });
  test(
    'Une publication supérieure ouvre le lien MEGA exact avec sa clé',
    () async {
      final release = await checkAppUpdate(
        platform: 'android',
        fetch: () async => manifest(),
        package: () async => installed('0.1.0', '1', 100),
      );
      expect(release!.url.toString(), 'https://mega.nz/file/apk#public-key');
    },
  );
  test(
    'Un lien modifié à version égale demande une installation réelle',
    () async {
      Future<AppRelease?> check(String id, int stamp) => checkAppUpdate(
        platform: 'android',
        fetch: () async => manifest(id: List.filled(64, id).join()),
        package: () async => installed('0.2.0', '2', stamp),
      );
      expect(await check('a', 100), isNull);
      expect(await check('b', 100), isNotNull);
      expect(
        await check('b', 100),
        isNotNull,
      ); // Seeing the alert does not dismiss it.
      expect(
        await check('b', 200),
        isNull,
      ); // Package update timestamp changed.
      expect(await check('b', 200), isNull);
    },
  );
  test(
    'Les publications désactivées, invalides et APK sur Windows ne bloquent pas',
    () async {
      expect(
        await checkAppUpdate(
          platform: 'windows',
          fetch: () async => throw StateError('no request'),
        ),
        isNull,
      );
      for (final data in [
        {...manifest(), 'enabled': false},
        manifest(url: 'javascript:bad'),
        manifest(url: 'https://user:password@mega.nz/file/apk'),
        manifest(version: 'annonce'),
      ]) {
        expect(
          await checkAppUpdate(
            platform: 'android',
            fetch: () async => data,
            package: () async => installed('0.1.0', '1', 100),
          ),
          isNull,
        );
      }
    },
  );
  testWidgets(
    'La mise à jour apparaît avant le village et cliquer ne la valide pas',
    (tester) async {
      final release = AppRelease(
        version: '0.2.0+2',
        installed: '0.1.0+1',
        url: Uri.parse('https://mega.nz/file/apk#key'),
        id: 'abc',
      );
      Uri? opened;
      bool updated = false;
      await tester.pumpWidget(
        MaterialApp(
          home: AppUpdateGate(
            check: () async => updated ? null : release,
            launch: (uri) async {
              opened = uri;
              return true;
            },
            child: const Scaffold(body: Text('Bienvenue au village')),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Mise à jour disponible'), findsOneWidget);
      expect(find.text('Bienvenue au village'), findsNothing);
      await tester.tap(find.text('Télécharger la mise à jour'));
      await tester.pump();
      expect(opened.toString(), 'https://mega.nz/file/apk#key');
      expect(find.text('Bienvenue au village'), findsNothing);
      updated = true;
      await tester.tap(find.text('Vérifier à nouveau'));
      await tester.pump();
      expect(find.text('Bienvenue au village'), findsOneWidget);
    },
  );
  testWidgets('Hors connexion au démarrage le jeu local reste accessible', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AppUpdateGate(
          check: () async => throw StateError('offline'),
          child: const Text('Jeu local disponible'),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Jeu local disponible'), findsOneWidget);
  });
}
