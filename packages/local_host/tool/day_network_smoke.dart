import 'classic_scenario_driver.dart';
import 'dart:async';
import '../lib/local_host.dart';

Future<void> main() async {
  final host = LocalHost();
  final clients = List.generate(4, (_) => LobbyClient());
  final subs = <StreamSubscription>[];
  final roles = <int, String>{};
  final private = <int, Map<String, dynamic>>{};
  final rooms = <int, Map<String, dynamic>>{};
  Future<void> until(bool Function() condition) async {
    for (var i = 0; i < 400 && !condition(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    if (!condition()) throw StateError('État de journée attendu non reçu.');
  }

  int revision() =>
      (host.publicSnapshot['game'] as Map)['phase_revision'] as int;
  try {
    await host.start(port: 0);
    for (var i = 0; i < 4; i++) {
      final index = i;
      subs.add(
        clients[i].events.listen((event) {
          if (event['type'] == 'game.role')
            roles[index] = event['role'] as String;
          if (event['type'] == 'game.private') private[index] = event;
          if (event['type'] == 'room.snapshot') rooms[index] = event;
        }),
      );
      await clients[i].connect('127.0.0.1:${host.port}', host.code, 'Jour $i');
      await until(() => clients[i].id != null);
      clients[i].setReady(true);
    }
    await until(() => host.launchError == null);
    host.startGame();
    final slots = (host.publicSnapshot['players'] as List)
        .map((player) => player['house_slot'])
        .toSet();
    if (slots.length != 4 || slots.contains(null))
      throw StateError('Maisons non distinctes.');
    await until(() => roles.length == 4);
    host.startNight(seconds: 60);
    nextClassic(host);
    nextClassic(host);
    nextClassic(host);
    await until(() => rooms.values.every((room) => room['phase'] == 'day'));
    clients.first.gameAction(
      'day.chat',
      revision(),
      text: 'Prêts pour le débat ?',
    );
    await until(
      () => rooms.values.every(
        (room) => ((room['game'] as Map)['day_messages'] as List).isNotEmpty,
      ),
    );
    host.startVote(seconds: 60);
    final targetIndex = roles.entries
        .firstWhere((entry) => entry.key != 0 && entry.value == 'villager')
        .key;
    final target = clients[targetIndex].id!;
    clients[0].gameAction('vote.cast', revision(), target: target);
    clients[1].gameAction('vote.cast', revision(), target: target);
    clients[2].gameAction('vote.cast', revision());
    await until(
      () => (host.publicSnapshot['game'] as Map)['votes_received'] == 3,
    );
    if (rooms.values.any(
      (room) => (room['game'] as Map).containsKey('vote_result'),
    ))
      throw StateError('Décompte révélé trop tôt.');
    if (private[3]?['vote_submitted'] == true)
      throw StateError('Bulletin attribué au mauvais joueur.');
    await clients[0].disconnect();
    await until(
      () => (host.snapshot['players'] as List).any(
        (p) => p['id'] == clients[0].id && p['connected'] == false,
      ),
    );
    private.remove(0);
    await clients[0].reconnect();
    await until(
      () =>
          private[0]?['vote_target'] == target &&
          private[0]?['vote_submitted'] == true,
    );
    nextClassic(host);
    await until(
      () => rooms.values.every((room) => room['phase'] == 'vote_result'),
    );
    final result = (host.publicSnapshot['game'] as Map)['vote_result'] as Map;
    if (result['eliminated'] != target ||
        result['blank'] != 1 ||
        result['abstentions'] != 1)
      throw StateError('Résultat erroné.');
    if (private[targetIndex]?['alive'] != false)
      throw StateError('Élimination non transmise.');
    host.spinSentence();
    await until(
      () => rooms.values.every(
        (room) => (room['game'] as Map)['sentence'] != null,
      ),
    );
    final sentence = (host.publicSnapshot['game'] as Map)['sentence'] as Map;
    if (rooms.values.any(
      (room) =>
          ((room['game'] as Map)['sentence'] as Map)['index'] !=
          sentence['index'],
    )) {
      throw StateError('La roue diffère entre les clients.');
    }
    if ((host.publicSnapshot['players'] as List)
            .map((p) => p['house_slot'])
            .toSet()
            .length !=
        4) {
      throw StateError('Une maison a changé après reconnexion.');
    }
    await until(
      () => rooms.values.every(
        (room) =>
            ((room['game'] as Map)['sentence'] as Map?)?['remaining_ms'] == 0,
      ),
    );
    host.continueAfterSentence();
    await until(() => rooms.values.every((room) => room['phase'] == 'sleep'));
    if ((host.publicSnapshot['game'] as Map)['night'] != 2)
      throw StateError('Nuit suivante absente.');
    nextClassic(host);
    await until(() => rooms.values.every((room) => room['phase'] == 'wolves'));
    final remaining =
        (host.publicSnapshot['game'] as Map)['remaining_ms'] as int;
    if (remaining > 60000 || remaining < 58000)
      throw StateError('Durée des appels non conservée.');
    print(
      'Jour réseau OK : chat partagé, bulletins privés, reprise de vote, décompte, élimination et nuit 2.',
    );
  } finally {
    for (final sub in subs) {
      await sub.cancel();
    }
    for (final client in clients) {
      await client.dispose();
    }
    await host.dispose();
  }
}
