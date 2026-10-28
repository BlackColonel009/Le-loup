import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mordeviel/main.dart';
import 'package:mordeviel/design/opening_screen.dart';
import 'package:mordeviel/joining/scan_invitation_screen.dart';

Future<void> openWelcome(WidgetTester tester) async {
  await tester.pumpWidget(
    MordevielApp(
      checkMaintenance: () async => {
        'local_enabled': true,
        'online_enabled': true,
      },
    ),
  );
  await tester.pump();
  await tester.tap(find.text('Passer'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
}

void main() {
  testWidgets(
    'Le scan demande un pseudo et l’annulation conserve le formulaire',
    (tester) async {
      await openWelcome(tester);
      await tester.ensureVisible(find.text('Jouer en local'));
      await tester.tap(find.text('Jouer en local'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Scanner pour rejoindre'));
      await tester.tap(find.text('Scanner pour rejoindre'));
      await tester.pumpAndSettle();
      expect(find.byType(ScanInvitationScreen), findsNothing);
      final pseudo = find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.decoration?.labelText == 'Ton pseudo',
      );
      await tester.scrollUntilVisible(
        pseudo,
        -180,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.enterText(pseudo, 'Alice');
      await tester.ensureVisible(find.text('Scanner pour rejoindre'));
      await tester.tap(find.text('Scanner pour rejoindre'));
      await tester.pumpAndSettle();
      expect(find.byType(ScanInvitationScreen), findsOneWidget);
      await tester.tap(find.text('Utiliser la saisie manuelle'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        pseudo,
        -180,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.widget<TextField>(pseudo).controller?.text, 'Alice');
      expect(find.byType(ScanInvitationScreen), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.windows),
  );
  testWidgets('Une seule ouverture, même après un retour à l’accueil', (
    tester,
  ) async {
    await openWelcome(tester);
    await tester.ensureVisible(find.text('Découvrir les cartes'));
    await tester.tap(find.text('Découvrir les cartes'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byType(OpeningScreen), findsNothing);
    expect(find.text('Mordeviel'), findsOneWidget);
  });
  testWidgets('L’accueil présente le projet', (tester) async {
    await openWelcome(tester);
    expect(find.text('Mordeviel'), findsOneWidget);
    expect(find.text('Une nuit. Des secrets.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Le salon valide le pseudo avant d’héberger', (tester) async {
    await openWelcome(tester);
    await tester.ensureVisible(find.text('Jouer en local'));
    await tester.tap(find.text('Jouer en local'));
    await tester.pumpAndSettle();
    expect(find.text('Rassemble ton village'), findsOneWidget);
    await tester.tap(find.text('Créer un salon · Je suis le MDJ'));
    await tester.pump();
    expect(
      find.text('Choisis un pseudo de 1 à 24 caractères.'),
      findsOneWidget,
    );
    final formScroll = find
        .descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Code du salon'),
      160,
      scrollable: formScroll,
    );
    expect(find.text('Code du salon'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Rejoindre le village'),
      160,
      scrollable: formScroll,
    );
    expect(find.text('Rejoindre le village'), findsOneWidget);
  });

  for (final size in [const Size(320, 568), const Size(1024, 600)]) {
    testWidgets('Accueil lisible à $size avec texte agrandi', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openWelcome(tester);
      await tester.scrollUntilVisible(find.text('Jouer en local'), 160);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Jouer en local'));
      await tester.pumpAndSettle();
      expect(find.text('Rassemble ton village'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
