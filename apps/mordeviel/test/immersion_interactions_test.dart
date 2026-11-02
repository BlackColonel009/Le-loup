import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mordeviel/cards/card_gallery.dart';
import 'package:mordeviel/cards/card_motion.dart';
import 'package:mordeviel/cards/classic_role.dart';
import 'package:mordeviel/services/immersion_preferences.dart';
import 'package:mordeviel/village/narrative_journal.dart';
import 'package:mordeviel/village/house_reaction.dart';

void main() {
  testWidgets('Une réaction inconnue disparaît sans erreur de fermeture', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HouseReaction(
            reaction: {'sticker': 'unknown', 'remaining_ms': 4000},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ImmersionPreferences.instance.vibrations = false;
    ImmersionPreferences.instance.lightEffects = false;
  });
  testWidgets(
    'Le coup d’œil disparaît au relâchement et à la perte du premier plan',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RoleCardViewer(
            role: configuredRole('werewolf'),
            ambience: CardAmbience.classic,
            covered: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final first = await tester.startGesture(
        tester.getCenter(find.byType(CardMotion)),
      );
      await tester.pump(const Duration(milliseconds: 650));
      expect(find.byKey(const ValueKey('secret-card-peek')), findsOneWidget);
      expect(find.text('Ma carte secrète'), findsOneWidget);
      await first.up();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('secret-card-peek')), findsNothing);
      final second = await tester.startGesture(
        tester.getCenter(find.byType(CardMotion)),
      );
      await tester.pump(const Duration(milliseconds: 650));
      expect(find.byKey(const ValueKey('secret-card-peek')), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('Carte masquée'), findsOneWidget);
      expect(find.byKey(const ValueKey('secret-card-peek')), findsNothing);
      await second.cancel();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.text('Carte masquée'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  test('Les préférences d’immersion sont conservées', () async {
    await ImmersionPreferences.instance.configure(
      haptics: false,
      sounds: false,
      light: true,
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('immersion_vibrations'), false);
    expect(prefs.getBool('immersion_card_sounds'), false);
    expect(prefs.getBool('immersion_light_effects'), true);
    await ImmersionPreferences.instance.initialize();
    expect(ImmersionPreferences.instance.lightEffects, true);
  });
  testWidgets('Le grimoire filtre les manches sans mélanger les événements', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NarrativeJournal(
            events: const [
              {
                'night': 1,
                'kind': 'phase',
                'phase': 'sleep',
                'label': 'Première nuit',
              },
              {
                'night': 2,
                'kind': 'death',
                'phase': 'dawn',
                'label': 'Dernière nuit',
              },
            ],
            describe: (event) => event['label'] as String,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manche 2'));
    await tester.pumpAndSettle();
    expect(find.text('Première nuit'), findsNothing);
    expect(find.text('Dernière nuit'), findsOneWidget);
    await tester.tap(find.text('Toute l’histoire'));
    await tester.pumpAndSettle();
    expect(find.text('Première nuit'), findsOneWidget);
  });
}
