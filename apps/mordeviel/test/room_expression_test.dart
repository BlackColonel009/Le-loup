import 'package:flutter_test/flutter_test.dart';
import 'package:local_host/local_host.dart';

void send(NightGame game, String id, String action, {String? text}) => game.act(
  id,
  {'action': action, 'phase_revision': game.revision, 'text': text},
);

void main() {
  test('Réactions de meute privées, temporaires et limitées en fréquence', () {
    var now = DateTime.utc(2026, 11, 1);
    final game = NightGame({
      'w': 'werewolf',
      'a': 'villager',
      'b': 'villager',
      'c': 'villager',
    }, clock: () => now);
    game.startNight();
    game.callNight('wolves');
    final sticker = stickerMessage(chatStickers.first);
    send(game, 'w', 'reaction.send', text: sticker);
    expect(game.publicState.containsKey('reactions'), false);
    expect(game.privateState('a').containsKey('reactions'), false);
    expect(game.privateState('w')['reactions'], hasLength(1));
    expect(
      () => send(game, 'a', 'reaction.send', text: sticker),
      throwsStateError,
    );
    expect(
      () => send(game, 'w', 'reaction.send', text: sticker),
      throwsStateError,
    );
    now = now.add(const Duration(seconds: 5));
    expect(game.privateState('w')['reactions'], isEmpty);
    send(game, 'w', 'reaction.send', text: sticker);
    expect(game.privateState('w')['reactions'], hasLength(1));
    game.advance();
    expect(game.privateState('w').containsKey('reactions'), false);
    expect(game.hostState['wolf_reactions'], isEmpty);
  });
  test('Droits vocaux calculés par rôle, phase, pause et décès', () {
    final game = NightGame({
      'w': 'werewolf',
      'a': 'villager',
      'b': 'villager',
      'c': 'villager',
    });
    game.startNight();
    game.callNight('wolves');
    expect(game.voiceAccess('w'), {'channel': 'wolves', 'publish': true});
    expect(game.voiceAccess('a')['channel'], null);
    expect(game.voiceAccess('host', host: true)['channel'], 'wolves');
    game.pause();
    expect(game.voiceAccess('w')['channel'], null);
    game.resume();
    game.advance();
    game.finishNight();
    game.advance();
    expect(game.phase, 'day');
    expect(game.voiceAccess('a'), {'channel': 'village', 'publish': true});
    game.setChatOpen(false);
    expect(game.voiceAccess('a')['publish'], false);
    expect(game.voiceAccess('host', host: true)['publish'], true);
    game.setChatOpen(true);
    game.startVote();
    for (final id in game.alive.toList()) {
      game.act(id, {
        'action': 'vote.cast',
        'phase_revision': game.revision,
        'target': 'a',
      });
    }
    game.advance();
    expect(game.voiceAccess('a')['publish'], false);
    expect(
      () => send(
        game,
        'a',
        'reaction.send',
        text: stickerMessage(chatStickers.first),
      ),
      throwsStateError,
    );
  });
  test(
    'Les réactions publiques ne sont ni des sélections ni un historique secret',
    () {
      final game = NightGame({
        'w': 'werewolf',
        'a': 'villager',
        'b': 'villager',
        'c': 'villager',
      });
      game.startNight();
      game.finishNight();
      game.advance();
      send(
        game,
        'a',
        'reaction.send',
        text: stickerMessage(chatStickers.first),
      );
      expect(game.publicState['reactions'], hasLength(1));
      expect(game.privateState('a').containsKey('confirmed_selection'), false);
      expect(
        () => send(game, 'b', 'reaction.send', text: '[[sticker:inconnu]]'),
        throwsArgumentError,
      );
      game.setChatOpen(false);
      expect(
        () => send(
          game,
          'b',
          'reaction.send',
          text: stickerMessage(chatStickers.first),
        ),
        throwsStateError,
      );
    },
  );
}
