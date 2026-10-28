import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_host/local_host.dart';
import 'night_panel_test.dart' show screen;

void main() {
  Map<String, dynamic> roomFor(NightGame g) => {
    'players': [
      for (final id in g.roles.keys) {'id': id, 'nickname': id.toUpperCase()},
    ],
    'game': g.publicState,
  };
  testWidgets(
    'La comparaison propose deux cibles et affiche son résultat privé sans erreur de rôle',
    (tester) async {
      final g = NightGame(
        {'s': 'seer', 'w': 'werewolf', 'a': 'villager', 'b': 'villager'},
        editions: {'s': 'intense'},
      );
      g.startNight();
      g.callNight('seer');
      String? command;
      List<String>? chosen;
      await tester.pumpWidget(
        screen(
          state: roomFor(g),
          private: g.privateState('s'),
          action: (action, revision, {target, save, kill, text, targets}) {
            command = action;
            chosen = targets;
          },
        ),
      );
      final button = find.widgetWithText(
        FilledButton,
        'Comparer deux camps (remplace la vision)',
      );
      await tester.ensureVisible(find.widgetWithText(FilterChip, 'W'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'W'));
      await tester.tap(find.widgetWithText(FilterChip, 'A'));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      expect(command, 'seer.compare');
      expect(chosen, unorderedEquals(['w', 'a']));
      g.act('s', {
        'phase_revision': g.revision,
        'action': command,
        'targets': chosen,
      });
      await tester.pumpWidget(
        screen(state: roomFor(g), private: g.privateState('s')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('camps différents'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Le Gardien royal propose son renforcement sans permettre de se viser',
    (tester) async {
      final g = NightGame(
        {'g': 'guardian', 'w': 'werewolf', 'a': 'villager', 'b': 'villager'},
        editions: {'g': 'intense'},
      );
      g.startNight();
      g.callNight('guardian');
      final abilities = g.privateState('g')['variant_abilities'] as List;
      expect(abilities.single['targets'], isNot(contains('g')));
      await tester.pumpWidget(
        screen(state: roomFor(g), private: g.privateState('g')),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Protection renforcée contre le poison'),
        findsWidgets,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
