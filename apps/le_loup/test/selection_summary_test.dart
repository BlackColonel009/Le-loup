import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'night_panel_test.dart' as fixture;

void main() {
  testWidgets('Sélection Voyante : auteur et cible, puis accusé de réception', (
    tester,
  ) async {
    final room = fixture.room('seer');
    final private = <String, dynamic>{
      'id': 's',
      'role': 'seer',
      'phase_revision': 2,
      'alive': true,
      'can_act': true,
    };
    await tester.pumpWidget(fixture.screen(state: room, private: private));
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Basile').last);
    await tester.pumpAndSettle();
    expect(
      find.text('Alice · Voyante → Basile\nSélection à confirmer'),
      findsOneWidget,
    );
    await tester.pumpWidget(
      fixture.screen(
        state: room,
        private: {
          ...private,
          'can_act': false,
          'confirmed_selection': {
            'actor': 's',
            'role': 'seer',
            'action': 'seer.inspect',
            'target': 'w',
          },
        },
      ),
    );
    expect(
      find.text('Alice · Voyante → Basile\nChoix confirmé'),
      findsOneWidget,
    );
  });

  testWidgets('Le MDJ voit précisément les deux potions confirmées', (
    tester,
  ) async {
    final room = fixture.room('witch');
    room['game_host'] = {
      'confirmed_selections': [
        {
          'actor': 's',
          'role': 'witch',
          'action': 'witch.potions',
          'save': true,
          'victim': 'w',
          'kill': 's',
        },
      ],
    };
    await tester.pumpWidget(fixture.screen(state: room, host: true));
    expect(
      find.text(
        'Alice · Sorcière → Vie : Basile · Mort : Alice\nChoix confirmé',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
