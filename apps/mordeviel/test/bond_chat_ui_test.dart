import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/village/village_chat.dart';
import 'card_variants_test.dart' show make;
import 'bond_card_variants_test.dart' show link;

void main() {
  testWidgets(
    'Le chat des amoureux envoie sur son canal privé et disparaît à sa fermeture',
    (tester) async {
      final g = make(roles: {'p': 'cupid'}, editions: {'p': 'intense'});
      link(g);
      String? command, sent;
      Widget scene() => MaterialApp(
        home: Scaffold(
          body: VillageChat(
            fullPage: true,
            room: {
              'phase': g.phase,
              'game': g.publicState,
              'features': ['house_reactions'],
              'players': [
                for (final id in g.roles.keys)
                  {'id': id, 'nickname': id.toUpperCase()},
              ],
            },
            privateState: g.privateState('a'),
            isHost: false,
            connected: true,
            onSend: (action, revision, text, {replyTo}) {
              command = action;
              sent = text;
            },
          ),
        ),
      );
      await tester.pumpWidget(scene());
      await tester.pump();
      expect(find.text('Échange des amoureux'), findsOneWidget);
      expect(find.byTooltip('Stickers'), findsOneWidget);
      expect(find.byTooltip('Réagir sur ma maison'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Un secret entre nous.');
      await tester.pump();
      await tester.tap(find.text('Envoyer'));
      expect(command, 'bond.chat');
      expect(sent, 'Un secret entre nous.');
      g.advance();
      await tester.pumpWidget(scene());
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      expect(find.text('Un secret entre nous.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
