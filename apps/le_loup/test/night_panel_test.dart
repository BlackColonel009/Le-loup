import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_loup/night_panel.dart';

Map<String, dynamic> room(String phase) => {
  'players': [
    {'id': 's', 'nickname': 'Alice'},
    {'id': 'w', 'nickname': 'Basile'},
  ],
  'game': {
    'phase': phase,
    'phase_revision': 2,
    'night': 1,
    'announcement': 'Voyante, ouvre les yeux.',
    'remaining_ms': 60000,
    'paused': false,
    'closed': false,
    'alive_ids': ['s', 'w'],
    'deaths': [],
  },
};

Widget screen({
  required Map<String, dynamic> state,
  Map<String, dynamic>? private,
  bool host = false,
  VoidCallback? next,
  SendNightAction? action,
  ValueChanged<String>? call,
  VoidCallback? finish,
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: NightPanel(
        room: state,
        privateState: private,
        isHost: host,
        connected: true,
        onStart: (_) {},
        onAdvance: next ?? () {},
        onPause: () {},
        onResume: () {},
        onCallNight: call,
        onFinishNight: finish,
        onAction:
            action ??
            (action, revision, {target, save, kill, text, targets}) {},
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'Cupidon envoie deux cibles distinctes avec la révision courante',
    (tester) async {
      List<String>? sent;
      final state = room('cupid');
      (state['game'] as Map).addAll(<String, Object>{
        'is_night': true,
        'timed': true,
      });
      await tester.pumpWidget(
        screen(
          state: state,
          private: {
            'id': 's',
            'role': 'cupid',
            'phase_revision': 2,
            'can_act': true,
            'alive': true,
            'ability': {
              'action': 'cupid.link',
              'label': 'Lier deux amoureux',
              'targets': ['s', 'w'],
              'min': 2,
              'max': 2,
              'can_pass': true,
            },
          },
          action: (action, revision, {target, save, kill, text, targets}) {
            expect(action, 'cupid.link');
            expect(revision, 2);
            sent = targets;
          },
        ),
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Lier deux amoureux'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.widgetWithText(FilterChip, 'Alice (moi)'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilterChip, 'Basile'));
      await tester.pump();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Lier deux amoureux'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Lier deux amoureux'));
      expect(sent, ['s', 'w']);
    },
  );
  testWidgets('Le Bouc éliminé peut sélectionner zéro électeur', (
    tester,
  ) async {
    List<String>? sent;
    final state = room('scapegoat');
    (state['game'] as Map).addAll(<String, Object>{
      'is_night': false,
      'timed': true,
    });
    await tester.pumpWidget(
      screen(
        state: state,
        private: {
          'id': 'g',
          'role': 'scapegoat',
          'phase_revision': 2,
          'can_act': true,
          'alive': false,
          'ability': {
            'action': 'scapegoat.voters',
            'label': 'Choisir les électeurs',
            'targets': ['s', 'w'],
            'min': 0,
            'max': 2,
            'can_pass': true,
          },
        },
        action: (action, revision, {target, save, kill, text, targets}) {
          sent = targets;
        },
      ),
    );
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Choisir les électeurs'),
    );
    await tester.tap(
      find.widgetWithText(FilledButton, 'Choisir les électeurs'),
    );
    expect(sent, isEmpty);
  });
  testWidgets(
    'Une Voyante infectée voit la meute sans commande de vision pendant la chasse',
    (tester) async {
      await tester.pumpWidget(
        screen(
          state: room('wolves'),
          private: {
            'id': 's',
            'role': 'seer',
            'is_pack': true,
            'phase_revision': 2,
            'can_act': true,
            'alive': true,
            'pack': ['s'],
            'choices': <String, String>{},
            'messages': <Map<String, String>>[],
          },
        ),
      );
      expect(find.text('Espace privé de la meute'), findsOneWidget);
      expect(find.text('Confirmer ma vision'), findsNothing);
    },
  );
  testWidgets(
    'Le MDJ choisit librement un appel et voit la dépendance Sorcière',
    (tester) async {
      String? selected;
      var finishes = 0;
      final state = room('sleep');
      state['game_host'] = {
        'night_actions': [
          {'action': 'seer', 'available': true, 'completed': false},
          {'action': 'wolves', 'available': true, 'completed': false},
          {
            'action': 'witch',
            'available': false,
            'completed': false,
            'reason': 'Résoudre l’attaque des loups d’abord.',
          },
        ],
      };
      await tester.pumpWidget(
        screen(
          state: state,
          host: true,
          call: (value) => selected = value,
          finish: () => finishes++,
        ),
      );
      final wolves = find.widgetWithText(
        OutlinedButton,
        'Appeler les Loups-Garous',
      );
      await tester.ensureVisible(wolves);
      await tester.tap(wolves);
      expect(selected, 'wolves');
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Appeler la Sorcière'),
            )
            .onPressed,
        isNull,
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Réveiller le village'),
      );
      await tester.tap(
        find.widgetWithText(FilledButton, 'Réveiller le village'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Terminer la nuit ?'), findsOneWidget);
      await tester.tap(find.text('Retour'));
      await tester.pumpAndSettle();
      expect(finishes, 0);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Un Villageois voit l’appel sans accéder au pouvoir', (
    tester,
  ) async {
    await tester.pumpWidget(
      screen(
        state: room('seer'),
        private: {
          'id': 'w',
          'role': 'villager',
          'phase_revision': 2,
          'can_act': false,
        },
      ),
    );
    expect(find.text('Voyante, ouvre les yeux.'), findsOneWidget);
    expect(find.text('Confirmer ma vision'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('La Voyante confirme une cible et la bonne phase', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      screen(
        state: room('seer'),
        private: {
          'id': 's',
          'role': 'seer',
          'phase_revision': 2,
          'can_act': true,
        },
        action: (action, revision, {target, save, kill, text, targets}) {
          expect(action, 'seer.inspect');
          expect(revision, 2);
          selected = target;
        },
      ),
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Basile').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmer ma vision'));
    expect(selected, 'w');
    expect(tester.takeException(), isNull);
  });
  testWidgets('Le MDJ doit confirmer la clôture anticipée', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      screen(state: room('seer'), host: true, next: () => calls++),
    );
    await tester.tap(find.text('Terminer cet appel'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.text('Continuer'));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });
}
