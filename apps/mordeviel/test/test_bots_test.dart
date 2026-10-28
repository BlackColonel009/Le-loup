import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_host/local_host.dart';

void main() {
  test(
    'Le bot loup suit le bulletin humain, y compris après un retour au choix initial',
    () {
      final bot = BotDecisions(random: Random(3));
      final game = <String, dynamic>{
        'phase': 'wolves',
        'phase_revision': 1,
        'alive_ids': ['bot', 'human', 'a', 'b'],
        'players': [
          {'id': 'bot', 'is_bot': true},
          {'id': 'human', 'is_bot': false},
          {'id': 'a', 'is_bot': false},
          {'id': 'b', 'is_bot': false},
        ],
      };
      for (final target in ['a', 'b', 'a']) {
        final move = bot.next('bot', game, {
          'phase_revision': 1,
          'role': 'werewolf',
          'can_act': true,
          'pack': ['bot', 'human'],
          'choices': {'bot': 'a', 'human': target},
        });
        expect(move?['target'], target);
      }
    },
  );
  test(
    'Les bots varient leur pouvoir, leur cible et la possibilité de passer',
    () {
      final commands = <String>{}, targets = <String>{};
      for (var seed = 0; seed < 60; seed++) {
        final game = NightGame(
          {'g': 'guardian', 'w': 'werewolf', 'a': 'villager', 'b': 'villager'},
          editions: {'g': 'intense'},
        );
        game.startNight();
        game.callNight('guardian');
        final move = BotDecisions(
          random: Random(seed),
        ).next('g', game.publicState, game.privateState('g'))!;
        commands.add(move['action'] as String);
        targets.addAll((move['targets'] as List? ?? []).cast<String>());
        game.act('g', move);
      }
      expect(
        commands,
        containsAll(['guardian.protect', 'guardian.ward', 'night.pass']),
      );
      expect(targets.length, greaterThan(1));
    },
  );
  test('Les loups trouvent une cible commune hors de leur meute', () {
    final game = NightGame({
      'w': 'werewolf',
      'x': 'werewolf',
      's': 'seer',
      'a': 'villager',
      'b': 'villager',
      'c': 'villager',
    });
    game.startNight();
    game.callNight('wolves');
    final targets = <String?>[];
    for (final id in ['w', 'x']) {
      final move = BotDecisions(
        random: Random(2),
      ).next(id, game.publicState, game.privateState(id))!;
      targets.add(move['target'] as String?);
      expect(['w', 'x'], isNot(contains(move['target'])));
      game.act(id, move);
    }
    expect(targets.first, targets.last);
  });

  test('Le bot respecte la pause et les révisions de phase', () {
    final game = NightGame({
      'w': 'werewolf',
      's': 'seer',
      'a': 'villager',
      'b': 'villager',
    });
    game.startNight();
    game.callNight('seer');
    final bot = BotDecisions();
    expect(
      bot.next('s', {
        ...game.publicState,
        'paused': true,
      }, game.privateState('s')),
      isNull,
    );
    expect(
      bot.next('s', game.publicState, {
        ...game.privateState('s'),
        'phase_revision': -1,
      }),
      isNull,
    );
  });

  test('La Voyante vote avec sa découverte privée', () {
    final game = NightGame({
      'w': 'werewolf',
      's': 'seer',
      'a': 'villager',
      'b': 'villager',
    });
    game.startNight();
    game.callNight('seer');
    game.act('s', {
      'action': 'seer.inspect',
      'phase_revision': game.revision,
      'target': 'w',
    });
    final bot = BotDecisions(random: Random(5));
    bot.next('s', game.publicState, game.privateState('s'));
    final move = bot.next(
      's',
      {
        'phase': 'voting',
        'phase_revision': 99,
        'alive_ids': ['w', 's', 'a', 'b'],
      },
      {
        ...game.privateState('s'),
        'phase_revision': 99,
        'can_vote': true,
        'vote_submitted': false,
      },
    );
    expect(move?['target'], 'w');
  });

  for (final edition in ['classic', 'intense', 'horror']) {
    test(
      'Tous les appels et pouvoirs $edition acceptent les décisions des bots',
      () {
        final roles = {
          'w': 'werewolf',
          'f': 'wolf_father',
          'alpha': 'alpha_wolf',
          'white': 'white_wolf',
          's': 'seer',
          'witch': 'witch',
          'meta': 'metamorph',
          'g': 'guardian',
          'c': 'cupid',
          'p': 'piper',
          'girl': 'little_girl',
          'h': 'hunter',
          'elder': 'elder',
          'sc': 'scapegoat',
          'i': 'idiot',
          'angel': 'angel',
          'sis1': 'sisters',
          'sis2': 'sisters',
          'a': 'villager',
          'b': 'villager',
          'd': 'villager',
          'e': 'villager',
        };
        final game = NightGame(
          roles,
          editions: {for (final id in roles.keys) id: edition},
        );
        final bots = {
          for (final id in roles.keys)
            id: BotDecisions(random: Random(id.hashCode)),
        };
        void react() {
          // Some powers have two successive decisions (peek + exchange).
          for (var step = 0; step < 3; step++) {
            for (final id in roles.keys) {
              final move = bots[id]!.next(
                id,
                game.publicState,
                game.privateState(id),
              );
              if (move == null) continue;
              // Wolves can revise their ballot; other powers report completion.
              expect(
                () => game.act(id, move),
                returnsNormally,
                reason: '$edition ${game.phase} $id ${move['action']}',
              );
            }
          }
        }

        game.startNight();
        var calls = 0;
        while (true) {
          final available = game.nightActions
              .where((a) => a['available'] == true)
              .toList();
          if (available.isEmpty) break;
          game.callNight(available.first['action'] as String);
          react();
          game.advance();
          expect(++calls, lessThan(20));
        }
        expect(calls, greaterThan(6));
        game.finishNight();
      },
    );
  }
}
