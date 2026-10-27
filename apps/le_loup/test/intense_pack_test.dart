import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_loup/village/village_map.dart';
import 'package:le_loup/village/ceremonies.dart';
import 'package:local_host/local_host.dart';

void main() {
  test(
    'Pack gratuit partagé et sentences validées sans modifier les rôles',
    () {
      final host = LocalHost();
      final deck = Map<String, int>.of(host.deck);
      final labels = List.generate(8, (i) => 'Sentence personnalisée $i');
      host.configure(deck, campOnly: false, pack: 'intense', sentences: labels);
      expect(host.publicSnapshot['visual_pack'], 'intense');
      expect(host.publicSnapshot['sentence_options'], labels);
      expect(host.deck, deck);
      expect(
        () => host.configure(deck, campOnly: false, pack: 'unknown'),
        throwsArgumentError,
      );
      expect(
        () => host.configure(deck, campOnly: false, sentences: ['']),
        throwsArgumentError,
      );
      final game = NightGame({
        'a': 'werewolf',
        'b': 'villager',
      }, sentenceOptions: labels);
      expect(game.publicState['sentence_options'], labels);
      expect(intenseVillagePlots.toSet().length, 20);
    },
  );
  testWidgets('Maisons Intense et roue personnalisée affichables', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              for (final state in ['day', 'night', 'eliminated'])
                SizedBox(
                  width: 140,
                  height: 140,
                  child: HouseSprite(state: state, intense: true),
                ),
              SentenceWheel(
                intense: true,
                isHost: true,
                onSpin: () {},
                name: (_) => 'Logan',
                game: {
                  'phase': 'vote_result',
                  'vote_result': {'eliminated': 'a'},
                  'sentence_options': NightGame.sentences,
                },
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
