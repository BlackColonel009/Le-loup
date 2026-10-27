import 'classic_scenario_driver.dart';
import 'dart:async';
import '../lib/local_host.dart';

Future<void> main() async {
  final host = LocalHost();
  final clients = List.generate(5, (_) => LobbyClient());
  final subscriptions = <StreamSubscription>[];
  final roles = <int, String>{};
  final private = <int, Map<String, dynamic>>{};
  final errors = <int, int>{};
  var leak = false;
  Future<void> until(bool Function() predicate) async {
    for (var i = 0; i < 100 && !predicate(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    if (!predicate()) throw StateError('Mise à jour attendue non reçue.');
  }

  int actor(String role) =>
      roles.entries.firstWhere((entry) => entry.value == role).key;
  String id(String role) => clients[actor(role)].id!;
  int revision() =>
      (host.publicSnapshot['game'] as Map)['phase_revision'] as int;
  try {
    await host.start(port: 0);
    host.configure({
      'villager': 1,
      'werewolf': 1,
      'seer': 1,
      'witch': 1,
      'hunter': 1,
    }, campOnly: false);
    for (var i = 0; i < clients.length; i++) {
      final index = i;
      subscriptions.add(
        clients[i].events.listen((event) {
          if (event['type'] == 'game.role')
            roles[index] = event['role'] as String;
          if (event['type'] == 'game.private') private[index] = event;
          if (event['type'] == 'error')
            errors[index] = (errors[index] ?? 0) + 1;
          if (event['type'] == 'room.snapshot') {
            final game = event['game'] as Map?;
            if (game != null &&
                (game.containsKey('visions') ||
                    game.containsKey('victim') ||
                    game.containsKey('wolf_choices')))
              leak = true;
          }
        }),
      );
      await clients[i].connect('127.0.0.1:${host.port}', host.code, 'Nuit $i');
      await until(() => clients[i].id != null);
      clients[i].setReady(true);
    }
    await until(() => host.launchError == null);
    host.startGame();
    await until(() => roles.length == 5);
    host.startNight(seconds: 60);
    nextClassic(host);
    clients[actor('villager')].gameAction(
      'seer.inspect',
      revision(),
      target: id('werewolf'),
    );
    await until(() => errors[actor('villager')] == 1);
    clients[actor('seer')].gameAction(
      'seer.inspect',
      revision(),
      target: id('werewolf'),
    );
    await until(() => private[actor('seer')]?.containsKey('vision') == true);
    if (private.entries.any(
      (entry) =>
          entry.key != actor('seer') && entry.value.containsKey('vision'),
    ))
      throw StateError('Vision diffusée.');
    final seerId = id('seer');
    await clients[actor('seer')].disconnect();
    await until(
      () => (host.snapshot['players'] as List).any(
        (p) => p['id'] == seerId && p['connected'] == false,
      ),
    );
    private.remove(actor('seer'));
    await clients[actor('seer')].reconnect();
    await until(() => private[actor('seer')]?.containsKey('vision') == true);
    nextClassic(host);
    clients[actor('werewolf')].gameAction(
      'wolves.chat',
      revision(),
      text: 'Message secret',
    );
    await until(
      () =>
          (private[actor('werewolf')]?['messages'] as List?)?.isNotEmpty ==
          true,
    );
    if (private.entries.any(
      (entry) =>
          entry.key != actor('werewolf') && entry.value.containsKey('messages'),
    ))
      throw StateError('Chat diffusé.');
    clients[actor('werewolf')].gameAction(
      'wolves.choose',
      revision(),
      target: id('hunter'),
    );
    await until(
      () => ((host.snapshot['game_host'] as Map)['wolf_choices'] as Map)
          .isNotEmpty,
    );
    nextClassic(host);
    await until(() => private[actor('witch')]?['victim'] == id('hunter'));
    clients[actor('witch')].gameAction(
      'witch.potions',
      revision(),
      save: false,
      kill: id('werewolf'),
    );
    await until(
      () => ((host.snapshot['game_host'] as Map)['witch_done'] as List)
          .isNotEmpty,
    );
    nextClassic(host);
    nextClassic(host);
    await until(() => private[actor('hunter')]?['can_act'] == true);
    clients[actor('hunter')].gameAction(
      'hunter.shoot',
      revision(),
      target: id('witch'),
    );
    await until(
      () => (host.snapshot['game_host'] as Map)['hunter_done'] == true,
    );
    nextClassic(host);
    if ((host.publicSnapshot['game'] as Map)['winner'] != 'village' || leak)
      throw StateError('Victoire ou confidentialité incorrecte.');
    print(
      'Nuit réseau OK : appels, permissions, secrets, chat, reprise de vision, potions, tir et victoire.',
    );
  } finally {
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    for (final client in clients) {
      await client.dispose();
    }
    await host.dispose();
  }
}
