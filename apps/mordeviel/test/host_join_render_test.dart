import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/design/game_theme.dart';
import 'package:mordeviel/joining/host_identity.dart';
import 'package:mordeviel/village/village_map.dart';

void main() {
  testWidgets(
    'Le village du MJ reste visible à l’arrivée de comptes connectés',
    (tester) async {
      final room = ValueNotifier<Map<String, dynamic>>({
        'code': 'ABC123',
        'phase': 'lobby',
        'visual_pack': 'classic',
        'players': <Map<String, dynamic>>[],
        'account_names': <String, String>{},
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: GameTheme.classic,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ValueListenableBuilder<Map<String, dynamic>>(
                valueListenable: room,
                builder: (_, snapshot, _) => VillageMap(
                  room: hostDisplayRoom(snapshot),
                  onHouse: (_) {},
                  onChat: () {},
                  animateGhosts: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      for (var count = 1; count <= 3; count++) {
        room.value = {
          ...room.value,
          'players': [
            for (var i = 0; i < count; i++)
              <String, dynamic>{
                'id': 'p$i',
                'nickname': 'Loup $i',
                'connected': true,
                'ready': i.isEven,
                'house_slot': i,
              },
          ],
          'account_names': {for (var i = 0; i < count; i++) 'p$i': 'Compte $i'},
        };
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull);
        expect(find.byType(VillageMap), findsOneWidget);
        expect(
          find.bySemanticsLabel(RegExp('Maison de Loup 0 \\(Compte 0\\)')),
          findsOneWidget,
        );
        expect((room.value['players'] as List).first['nickname'], 'Loup 0');
      }
      await tester.pumpWidget(const SizedBox());
      room.dispose();
    },
  );
}
