import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/coins/creator_gift.dart';
import 'package:mordeviel/design/game_theme.dart';
import 'package:mordeviel/social/social_api.dart';
import 'package:mordeviel/social/social_service.dart';
import 'package:mordeviel/store/store_screen.dart';

class ShopApi extends SocialApi {
  int balance = 1200, purchases = 0, gifts = 0;
  bool owned = false, unavailable = false;
  Map<String, dynamic>? sent;
  Map<String, dynamic> get gift => {
    'user_id': 42,
    'claimed': gifts > 0,
    'message': 'Le Créateur t’offre 100 Lunes d’or. — Logan R.D',
    'balance': balance,
  };
  Map<String, dynamic> get border => {
    'id': 'border-ruby',
    'kind': 'border',
    'role_id': 'ruby',
    'title': 'Rubis ardent',
    'coin_price': 500,
    'owned': owned,
    'bonus': [],
    'border': {
      'id': 'ruby',
      'title': 'Rubis ardent',
      'effect': 'orbit',
      'colors': ['#DB4861', '#FFE0D8'],
    },
  };
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    Map<String, dynamic>? body,
    String? deviceToken,
  }) async {
    if (unavailable) throw const SocialError(503, 'Connexion indisponible');
    if (path == '/shop/me') {
      return {
        'user_id': 42,
        'balance': balance,
        'day': '2026-11-04',
        'next_rotation': '2099-01-01T00:00:00Z',
        'products': [border],
      };
    }
    if (path == '/shop/purchase') {
      purchases++;
      sent = body;
      owned = true;
      balance -= 500;
      return {
        'user_id': 42,
        'balance': balance,
        'granted': ['border-ruby'],
        'already_owned': false,
      };
    }
    if (path == '/coins/gifts/0.3.5') return gift;
    if (path == '/coins/gifts/0.3.5/claim') {
      gifts++;
      balance += 100;
      return gift;
    }
    throw StateError(path);
  }
}

void main() {
  late SocialApi old;
  late ShopApi api;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    old = SocialApi.instance;
    api = ShopApi();
    SocialApi.instance = api;
    SocialService.instance.userId = 42;
  });
  tearDown(() {
    SocialApi.instance = old;
    SocialService.instance.userId = null;
  });
  Widget app(Widget child) =>
      MaterialApp(theme: GameTheme.classic, home: child);
  Future<void> loadShop(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: GameTheme.classic,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const StoreScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> buyButton(WidgetTester tester) async {
    final buy = find.byKey(const ValueKey('buy-border-ruby'));
    await tester.scrollUntilVisible(
      buy,
      180,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.ensureVisible(buy);
    await tester.pump();
    await tester.tap(buy);
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets('Achat confirmé : solde débité et article acquis', (
    tester,
  ) async {
    await loadShop(tester);
    expect(find.text(shopNotice), findsOneWidget);
    expect(find.text('1200 Lunes d’or'), findsOneWidget);
    await buyButton(tester);
    expect(find.text('Confirmer l’achat'), findsOneWidget);
    expect(find.textContaining('Il te restera 700'), findsOneWidget);
    await tester.tap(find.text('Confirmer l’achat'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(api.purchases, 1);
    expect(api.sent, {
      'product_id': 'border-ruby',
      'day': '2026-11-04',
      'expected_price': 500,
      'source': 'shop',
    });
    expect(SocialService.instance.coinBalance, 700);
    expect(find.text('Acquis'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Annuler et manquer de lunes ne déclenchent aucun débit', (
    tester,
  ) async {
    await loadShop(tester);
    await buyButton(tester);
    await tester.tap(find.text('Annuler'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(api.purchases, 0);
    api.balance = 100;
    await tester.tap(find.byTooltip('Actualiser les offres'));
    await tester.pump();
    await buyButton(tester);
    expect(find.textContaining('Il te manque 400'), findsOneWidget);
    expect(api.purchases, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Une panne affiche une explication sans offres fictives', (
    tester,
  ) async {
    api.unavailable = true;
    await loadShop(tester);
    expect(
      find.textContaining('Les offres sont indisponibles'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('buy-border-ruby')), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final size in [const Size(360, 800), const Size(844, 390)]) {
    testWidgets('Boutique lisible en $size avec texte agrandi', (tester) async {
      await loadShop(tester, size: size, scale: 1.4);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('buy-border-ruby')),
        140,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Le cadeau de version crédite la bourse après réclamation', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(Scaffold(body: CreatorGiftDialog(gift: api.gift))),
    );
    expect(find.text('+100 Lunes d’or'), findsOneWidget);
    await tester.tap(find.text('Réclamer mes 100 lunes'));
    await tester.pump();
    expect(api.gifts, 1);
    expect(SocialService.instance.coinBalance, 1300);
    expect(find.text('100 lunes dans ta bourse !'), findsOneWidget);
    expect(find.text('Réclamer mes 100 lunes'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
