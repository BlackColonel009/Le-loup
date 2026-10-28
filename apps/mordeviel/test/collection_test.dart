import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/design/game_theme.dart';
import 'package:mordeviel/social/social_api.dart';
import 'package:mordeviel/store/collection_admin.dart';
import 'package:mordeviel/store/collection_screen.dart';
import 'package:mordeviel/store/collector_welcome.dart';

class CollectionApi extends SocialApi {
  bool free = true;
  int days = 12;
  bool owned = false;
  bool visited = false;
  Map<String, dynamic> state() => {
    'free_access': free,
    'free_until': '2026-11-08',
    'free_days_remaining': free ? days : 0,
    'free_days_configured': days,
    'day': '2026-10-28',
    'daily_ids': ['card-intense-seer'],
    'trials': [],
    'products': [
      for (final theme in ['classic', 'intense', 'horror'])
        {
          'id': 'card-$theme-seer',
          'kind': 'card',
          'theme': theme,
          'role_id': 'seer',
          'title': 'Voyante',
          'owned': theme == 'classic' || owned,
          'accessible': theme == 'classic' || free || owned,
          'locked': theme != 'classic' && !free && !owned,
          'access_reason': theme == 'classic' || owned
              ? 'owned'
              : free
              ? 'free_preview'
              : 'locked',
          'free_days_remaining': theme == 'classic' || owned
              ? null
              : free
              ? days
              : 0,
          'price_minor': 250,
          'currency': 'XOF',
          'visible': 1,
          'shop': 1,
          'collector': 1,
          'bonus': [],
          'claimable': theme != 'classic' && free && !owned,
          'purchase_label': 'Ajouter gratuitement',
        },
    ],
  };
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? deviceToken,
  }) async {
    if (path == '/collection/me' || path == '/community/admin/collection') {
      return state();
    }
    if (path == '/community/admin/collection/settings') {
      free = body!['free_access'] as bool;
      days = body['free_days'] as int? ?? days;
      return {'ok': true};
    }
    if (path == '/collection/claim') {
      owned = true;
      return {
        'ok': true,
        'granted': [body!['product_id']],
      };
    }
    if (path == '/collection/collector/visit') {
      final show = !visited;
      visited = true;
      return {'show': show};
    }
    throw StateError(path);
  }
}

void main() {
  late SocialApi previous;
  late CollectionApi api;
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_COLLECTION')) {
      await (FontLoader(
        'VillageSans',
      )..addFont(rootBundle.load('assets/fonts/SourceSans3[wght].ttf'))).load();
      final bytes = await File('C:/Windows/Fonts/arial.ttf').readAsBytes();
      await (FontLoader(
        'CollectionPreview',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    }
  });
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    previous = SocialApi.instance;
    api = CollectionApi();
    SocialApi.instance = api;
  });
  tearDown(() => SocialApi.instance = previous);
  Widget app(Widget child) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: GameTheme.classic.copyWith(
      textTheme: GameTheme.classic.textTheme.apply(
        fontFamily: const bool.fromEnvironment('CAPTURE_COLLECTION')
            ? 'CollectionPreview'
            : null,
      ),
    ),
    home: child,
  );
  testWidgets(
    'Le prix laisse place au nombre de jours gratuits et une acquisition persiste',
    (tester) async {
      await tester.pumpWidget(app(const CollectionScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Intense'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Gratuit · encore 12 jours'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(find.text('Ajouter gratuitement').first);
      await tester.pumpAndSettle();
      expect(find.text('Prix prévu : 250 XOF'), findsNothing);
      await tester.tap(find.text('Ajouter gratuitement').first);
      await tester.pumpAndSettle();
      expect(api.owned, isTrue);
      expect(find.text('Dans ta collection'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Le dashboard active puis retire les restrictions de test', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        CollectionAdminScreen(
          request: (path, {method = 'GET', body}) =>
              api.request('/community/$path', method: method, body: body),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Activer les restrictions — test'));
    await tester.pumpAndSettle();
    expect(api.free, isFalse);
    expect(find.text('Rétablir l’accès gratuit'), findsOneWidget);
    await tester.tap(find.text('Rétablir l’accès gratuit'));
    await tester.pumpAndSettle();
    expect(api.free, isTrue);
  });
  testWidgets('Les chaînes bougent et respectent la réduction des animations', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        const SizedBox(
          width: 200,
          height: 300,
          child: LockedCardVisual(
            locked: true,
            horror: true,
            child: ColoredBox(color: Colors.blue),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      tester
          .widget<Transform>(find.byType(Transform).first)
          .transform
          .storage[12],
      isNot(0),
    );
    await tester.pumpWidget(
      app(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: LockedCardVisual(
            locked: true,
            horror: true,
            child: ColoredBox(color: Colors.blue),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(
      tester
          .widget<Transform>(find.byType(Transform).first)
          .transform
          .storage[12],
      0,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Aperçu du Collectionneur et des verrous', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    for (final entry in [
      ('collector', const CollectionScreen(initialTab: 1)),
      ('intense-lock', const CollectionScreen()),
    ]) {
      api.free = entry.$1 == 'collector';
      await tester.pumpWidget(RepaintBoundary(key: key, child: app(entry.$2)));
      await tester.pump(const Duration(milliseconds: 400));
      if (entry.$1 != 'collector') {
        await tester.tap(find.widgetWithText(ChoiceChip, 'Intense'));
        await tester.pump(const Duration(milliseconds: 150));
        await tester.scrollUntilVisible(
          find.text('À collectionner'),
          200,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView).first,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.ensureVisible(find.text('À collectionner'));
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_COLLECTION')) {
        await tester.runAsync(() async {
          for (final asset in ['collector', 'gold_lock', 'horror_chains']) {
            await precacheImage(
              AssetImage('assets/store/$asset.png'),
              key.currentContext!,
            );
          }
        });
        await tester.pump();
      }
      if (const bool.fromEnvironment('CAPTURE_COLLECTION')) {
        await tester.runAsync(() async {
          final image =
              await (key.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '../../.tmp/collection-${entry.$1}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    }
  });
  testWidgets('La fenêtre du Collectionneur est refermable et quotidienne', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDailyCollector(context),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('Psst… mes trouvailles du jour !'), findsOneWidget);
    await tester.tap(find.byTooltip('Continuer l’aventure'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });
}
