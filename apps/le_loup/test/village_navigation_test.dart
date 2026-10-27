import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_loup/village/village_navigation.dart';
import 'package:le_loup/village/village_chat.dart';

void main() {
  for (final size in [const Size(360, 740), const Size(900, 420)]) {
    testWidgets('Menu et conseil adaptatifs à $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var destination = VillageDestination.village;
      var phase = 'day';
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return VillageNavigation(
                  destination: destination,
                  phase: phase,
                  isHost: true,
                  code: '123456',
                  onSelect: (value) => setState(() => destination = value),
                  onCodex: () {},
                  village: const Text('Carte du village'),
                  preparation: const Text('Composition des rôles'),
                  chat: const Text('Messages autorisés'),
                  actions: const Text('Bulletins secrets'),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Menu du village'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Conseil du village').last);
      await tester.pumpAndSettle();
      expect(find.text('Messages autorisés'), findsOneWidget);
      await tester.tap(find.text('Réunion et vote'));
      await tester.pumpAndSettle();
      expect(find.text('Bulletins secrets'), findsOneWidget);
      update(() => phase = 'wolves');
      await tester.pumpAndSettle();
      expect(
        find.text('Le conseil se réunit au lever du jour'),
        findsOneWidget,
      );
      expect(find.text('Messages autorisés'), findsNothing);
      await tester.tap(find.text('Voir la phase en cours'));
      await tester.pumpAndSettle();
      expect(find.text('Bulletins secrets'), findsOneWidget);
      expect(tester.takeException(), isNull);
      update(() => phase = 'vote_result');
      await tester.pumpAndSettle();
      expect(find.text('Bulletins secrets'), findsOneWidget);
      update(() => phase = 'hunter');
      await tester.pumpAndSettle();
      expect(find.text('Bulletins secrets'), findsOneWidget);
      expect(find.text('Le conseil se réunit au lever du jour'), findsNothing);
      update(() {
        destination = VillageDestination.council;
        phase = 'voting';
      });
      await tester.pumpAndSettle();
      expect(find.text('Bulletins secrets'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('La page discussion garde le secret de la meute', (tester) async {
    var sent = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VillageChat(
            fullPage: true,
            room: {
              'phase': 'wolves',
              'players': [
                {'id': 'wolf', 'nickname': 'Loup'},
              ],
              'game': {'phase_revision': 4, 'day_messages': []},
            },
            privateState: const {
              'role': 'villager',
              'alive': true,
              'can_act': false,
              'messages': [
                {'author': 'wolf', 'text': 'Message secret'},
              ],
            },
            isHost: false,
            connected: true,
            onSend: (_, _, _) => sent = true,
          ),
        ),
      ),
    );
    expect(find.text('Message secret'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Discussion fermée'), findsOneWidget);
    expect(sent, isFalse);
  });
}
