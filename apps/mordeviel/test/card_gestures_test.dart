import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/cards/card_gallery.dart';
import 'package:mordeviel/cards/card_motion.dart';
import 'package:mordeviel/cards/classic_role.dart';
import 'package:mordeviel/services/immersion_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ImmersionPreferences.instance.vibrations = false;
    ImmersionPreferences.instance.cardSounds = false;
    ImmersionPreferences.instance.lightEffects = false;
  });

  Future<void> open(
    WidgetTester tester, {
    bool covered = false,
    bool reduced = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: child!,
        ),
        home: RoleCardViewer(
          role: configuredRole('werewolf'),
          ambience: CardAmbience.classic,
          covered: covered,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double angle(WidgetTester tester) =>
      tester.widget<CardMotion>(find.byType(CardMotion)).halfTurns;

  testWidgets('Le recto et les règles suivent le doigt dans les deux sens', (
    tester,
  ) async {
    await open(tester);
    final card = find.byType(CardMotion);
    final width = tester.getSize(card).width;
    final finger = await tester.startGesture(tester.getCenter(card));
    await finger.moveBy(const Offset(25, 0));
    await tester.pump(const Duration(milliseconds: 30));
    await finger.moveBy(Offset(width * .6, 0));
    await tester.pump(const Duration(milliseconds: 30));
    expect(angle(tester), greaterThan(.5));
    expect(find.text('Camp : Loups-Garous'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    await finger.up();
    await tester.pumpAndSettle();
    expect(angle(tester), 1);
    await tester.drag(card, Offset(-width * .8, 0));
    await tester.pumpAndSettle();
    expect(angle(tester), 0);
    expect(find.text('Retourner la carte'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Une petite inclinaison revient en place sans cacher la carte', (
    tester,
  ) async {
    await open(tester);
    final card = find.byType(CardMotion);
    final center = tester.getCenter(card);
    final finger = await tester.startGesture(center + const Offset(55, 45));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    final tilted = tester
        .widget<Transform>(find.byKey(const ValueKey('card-pose')))
        .transform;
    expect(tilted.entry(0, 2).abs(), greaterThan(.02));
    await finger.moveBy(const Offset(0, 25));
    await tester.pump(const Duration(milliseconds: 30));
    await finger.up();
    await tester.pumpAndSettle();
    final settled = tester
        .widget<Transform>(find.byKey(const ValueKey('card-pose')))
        .transform;
    expect(settled.entry(0, 2), closeTo(0, .002));
    expect(find.byType(RoleCardViewer), findsOneWidget);
    expect(angle(tester), 0);
  });

  testWidgets('Un lancer garde son élan et peut être rattrapé au toucher', (
    tester,
  ) async {
    await open(tester);
    final card = find.byType(CardMotion);
    await tester.fling(card, const Offset(170, 0), 1800);
    await tester.pump(const Duration(milliseconds: 40));
    final moving = angle(tester);
    expect((moving - moving.roundToDouble()).abs(), greaterThan(.001));
    final finger = await tester.startGesture(tester.getCenter(card));
    await tester.pump(const Duration(milliseconds: 160));
    expect(angle(tester), closeTo(moving, .001));
    await finger.up();
    await tester.pumpAndSettle();
    expect(angle(tester), anyOf(0.0, 1.0));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Le glissement découvre une carte secrète, puis autorise les règles',
    (tester) async {
      await open(tester, covered: true);
      final card = find.byType(CardMotion);
      await tester.drag(card, Offset(tester.getSize(card).width * .8, 0));
      await tester.pumpAndSettle();
      expect(find.text('Ma carte secrète'), findsNothing);
      expect(find.text('Retourner la carte'), findsOneWidget);
      await tester.tap(find.text('Retourner la carte'));
      await tester.pumpAndSettle();
      expect(find.text('Camp : Loups-Garous'), findsOneWidget);
    },
  );

  testWidgets('Les gestes fonctionnent aussi sans animations automatiques', (
    tester,
  ) async {
    await open(tester, reduced: true);
    final card = find.byType(CardMotion);
    await tester.drag(card, Offset(tester.getSize(card).width * .8, 0));
    await tester.pumpAndSettle();
    expect(angle(tester), 1);
    expect(find.text('Voir l’illustration'), findsOneWidget);
  });

  testWidgets('Annuler un glissement ne découvre pas définitivement le rôle', (
    tester,
  ) async {
    await open(tester, covered: true);
    final card = find.byType(CardMotion);
    final finger = await tester.startGesture(tester.getCenter(card));
    await finger.moveBy(const Offset(25, 0));
    await tester.pump();
    await finger.moveBy(Offset(tester.getSize(card).width * .6, 0));
    await tester.pump();
    await finger.cancel();
    await tester.pumpAndSettle();
    expect(find.text('Ma carte secrète'), findsOneWidget);
    expect(find.text('Découvrir ma carte'), findsOneWidget);
    expect(angle(tester), 0);
    expect(tester.takeException(), isNull);
  });
}
