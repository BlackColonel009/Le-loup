import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/cards/game_codex.dart';
import 'package:mordeviel/room_compatibility.dart';

void main() {
  test('Un salon ancien ou une composition invalide sont refusés', () {
    expect(
      hasRoomConfiguration({'type': 'room.snapshot', 'players': []}),
      isFalse,
    );
    final valid = <String, dynamic>{
      'deck': {
        'villager': 3,
        'werewolf': 1,
        'seer': 0,
        'witch': 0,
        'hunter': 0,
      },
      'seer_camp_only': false,
    };
    expect(hasRoomConfiguration(valid), isTrue);
    expect(hasRoomConfiguration({...valid, 'deck': null}), isFalse);
    expect(
      hasRoomConfiguration({
        ...valid,
        'deck': {'villager': '3'},
      }),
      isFalse,
    );
  });

  testWidgets('Le Codex gère un ancien salon sans planter', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showGameCodex(context, {'players': []}),
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('Salon à recréer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
