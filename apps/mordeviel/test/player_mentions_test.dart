import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/chat/player_mentions.dart';

void main() {
  testWidgets(
    '@ opens suggestions, filters accents and inserts a whole spaced nickname',
    (tester) async {
      final controller = TextEditingController(), focus = FocusNode();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PlayerMentionSuggestions(
                  controller: controller,
                  focusNode: focus,
                  players: const [
                    {'id': 'a', 'nickname': 'Bot Léa 1', 'is_bot': true},
                    {'id': 'b', 'nickname': 'Hugo', 'is_bot': false},
                  ],
                ),
                TextField(controller: controller, focusNode: focus),
              ],
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Bonjour @');
      await tester.pump();
      expect(find.text('@Bot Léa 1'), findsOneWidget);
      expect(find.text('@Hugo'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Bonjour @lea');
      await tester.pump();
      expect(find.text('@Hugo'), findsNothing);
      await tester.tap(find.text('@Bot Léa 1'));
      await tester.pump();
      expect(controller.text, 'Bonjour @Bot Léa 1 ');
      expect(controller.selection.baseOffset, controller.text.length);
      expect(find.byKey(const ValueKey('player-mention-list')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      focus.dispose();
    },
  );
}
