import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_host/local_host.dart';
import 'package:mordeviel/content/downloads_screen.dart';
import 'package:mordeviel/content/pack_messages.dart';
import 'package:mordeviel/content/pack_store_native.dart';
import 'package:mordeviel/content/require_packs.dart';

class TestPacks extends PackStore {
  final ready = <String>{};
  bool offline = false;
  @override
  bool installed(String id) => ready.contains(id);
  @override
  Future<void> initialize() async {}
  @override
  Future<void> refresh() async {
    if (offline) {
      error = 'Catalogue inaccessible. Vérifie Internet et réessaie.';
      throw const SocketException('offline');
    }
    packs.clear();
    for (final id in ['horror-cards', 'voice-ghost', 'stickers-classic']) {
      packs.add({'id': id, 'title': packLabel(id), 'size': 100, 'files': []});
    }
    notifyListeners();
  }

  @override
  Future<void> install(String id) async {
    ready.add(id);
    notifyListeners();
  }
}

void main() {
  testWidgets('Le modal reste lisible sur un petit téléphone avec grand texte', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
          child: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => ensurePacksAvailable(
                  context,
                  ['horror-cards', 'horror-village', 'voice-ghost'],
                  reason:
                      'Ces packs sont nécessaires pour jouer avec le thème choisi.',
                  store: TestPacks(),
                ),
                child: const Text('Continuer'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(find.text('Packs à télécharger'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();
  });
  test(
    'Un refus de collection conserve l’explication sans accuser Internet',
    () {
      final failure = OnlineGameException.response(
        403,
        '{"detail":"Ce thème est verrouillé dans ta collection."}',
      );
      expect(
        gameFailureMessage(failure),
        'Ce thème est verrouillé dans ta collection.',
      );
      expect(gameFailureMessage(failure), isNot(contains('Internet')));
    },
  );
  test('Une erreur HTML ne devient jamais le message visible', () {
    final message = gameFailureMessage(
      OnlineGameException.response(502, '<html>Bad Gateway</html>'),
    );
    expect(message, contains('momentanément indisponible'));
    expect(message, isNot(contains('<html>')));
  });
  test(
    'Catalogue, espace disque, corruption et réseau ont des explications distinctes',
    () {
      expect(
        packFailureMessage(
          const FileSystemException('disk', '', OSError('full', 112)),
        ),
        contains('espace'),
      );
      expect(
        packFailureMessage(const FormatException('sha')),
        contains('endommagé'),
      );
      expect(
        packFailureMessage(TimeoutException('wait')),
        contains('Internet'),
      );
      expect(
        packFailureMessage(const PackRequestException(404)),
        contains('Actualise le catalogue'),
      );
      expect(downloadablePackForAsset('neural/ghost/preview.wav'), isNull);
      expect(
        downloadablePackForAsset('neural/ghost/mdj_wolves.wav'),
        'voice-ghost',
      );
      expect(downloadablePackForAsset('neural/classic_male/sleep.wav'), isNull);
    },
  );

  testWidgets(
    'Pack absent : modal précis, téléchargement ciblé puis retour à l’action',
    (tester) async {
      final store = TestPacks();
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () async {
                  result = await ensurePacksAvailable(
                    context,
                    ['horror-cards'],
                    reason: 'Ces cartes sont nécessaires pour jouer.',
                    store: store,
                  );
                },
                child: const Text('Continuer'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();
      expect(find.text('Packs à télécharger'), findsOneWidget);
      expect(find.text('• Horreur · Cartes'), findsOneWidget);
      expect(result, isNull);
      await tester.tap(find.text('Ouvrir les téléchargements'));
      await tester.pumpAndSettle();
      expect(find.byType(DownloadsScreen), findsOneWidget);
      expect(
        tester
            .widget<DownloadsScreen>(find.byType(DownloadsScreen))
            .requiredPackIds,
        {'horror-cards'},
      );
      await tester.ensureVisible(
        find.text('Télécharger les packs nécessaires'),
      );
      await tester.tap(find.text('Télécharger les packs nécessaires'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Revenir au jeu'));
      await tester.tap(find.text('Revenir au jeu'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Plus tard annule l’action sans erreur serveur', (tester) async {
    final store = TestPacks();
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await ensurePacksAvailable(
                  context,
                  ['voice-ghost'],
                  reason: 'Le pack de cette voix est nécessaire.',
                  store: store,
                );
              },
              child: const Text('Continuer'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plus tard'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(find.byType(DownloadsScreen), findsNothing);
  });
  testWidgets('Un pack installé laisse passer sans requête réseau', (
    tester,
  ) async {
    final store = TestPacks()..offline = true;
    store.ready.add('horror-cards');
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                result = await ensurePacksAvailable(
                  context,
                  ['horror-cards'],
                  reason: 'Cartes',
                  store: store,
                );
              },
              child: const Text('Continuer'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
    expect(store.error, isNull);
  });
}
