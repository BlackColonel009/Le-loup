import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_host/card_variants.dart';
import 'package:mordeviel/cards/card_gallery.dart';
import 'package:mordeviel/cards/classic_role.dart';

void main() {
  test('Les 19 familles ont deux fiches complètes, dont le titre de Maire', () {
    expect(cardVariantRules, hasLength(38));
    expect(variantRoleIds, hasLength(18));
    for (final card in collectionCards) {
      for (final edition in ['intense', 'horror']) {
        final variant = cardVariant(card.id, edition)!;
        expect(variant['name'], isNotEmpty);
        expect(variant['summary'], isNotEmpty);
        expect(variant['rules'], isNotEmpty);
        final configured = configuredRole(card.id, edition: edition);
        expect(configured.name, contains(variant['name']!));
        expect(configured.details, contains(variant['rules']!));
      }
    }
  });

  testWidgets('Les 38 rectos restent lisibles avec les caractères agrandis', (
    tester,
  ) async {
    for (final card in collectionCards) {
      for (final ambience in [CardAmbience.intense, CardAmbience.horror]) {
        final role = configuredRole(card.id, edition: ambience.asset);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
            ),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 300,
                  height: 450,
                  child: RoleCardFront(role: role, ambience: ambience),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(
          find.text(cardVariant(card.id, ambience.asset)!['name']!),
          findsOneWidget,
        );
        expect(
          tester.takeException(),
          isNull,
          reason: '${card.id}:${ambience.asset}',
        );
      }
    }
  });
}
