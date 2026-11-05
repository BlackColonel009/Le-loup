import 'dart:async';
import '../lib/local_host.dart';

Future<void> until(bool Function() condition) async {
  final end = DateTime.now().add(const Duration(seconds: 8));
  while (!condition()) {
    if (DateTime.now().isAfter(end)) throw StateError('Network timeout');
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

Future<void> main() async {
  final host = LocalHost();
  final clients = <LobbyClient>[];
  final subscriptions = <StreamSubscription>[];
  final private = <int, Map<String, dynamic>>{};
  final ids = <int, String>{};
  final themed = <int>{};
  final sentences = List.generate(8, (i) => 'Sentence $i');
  var leak = false;
  try {
    await host.start(port: 0);
    host.configure(
      {for (final role in roleIds) role: role == 'sisters' ? 2 : 1},
      campOnly: false,
      pack: 'intense',
      sentences: sentences,
    );
    for (var i = 0; i < roleIds.length + 1; i++) {
      final index = i, client = LobbyClient();
      clients.add(client);
      subscriptions.add(
        client.events.listen((event) {
          if (event['type'] == 'room.joined')
            ids[index] = event['id'] as String;
          if (event['type'] == 'game.private') private[index] = event;
          if (event['type'] == 'room.snapshot') {
            if (event['visual_pack'] == 'intense' &&
                (event['sentence_options'] as List?)?.first == 'Sentence 0') {
              themed.add(index);
            }
            final game = event['game'] as Map?;
            if (event.containsKey('assignments') ||
                event.containsKey('game_host') ||
                game != null &&
                    [
                      'lovers',
                      'charmed',
                      'pending_infections',
                      'protected',
                      'night_actions',
                    ].any(game.containsKey))
              leak = true;
          }
        }),
      );
      await client.connect(
        '127.0.0.1:${host.port}',
        host.code,
        'Extension $index',
      );
      await until(() => ids.containsKey(index));
      client.setReady(true);
    }
    await until(() => host.launchError == null);
    await until(() => themed.length == roleIds.length + 1);
    host.startGame();
    check(
      (host.snapshot['game'] as Map)['sentence_options'].first == 'Sentence 0',
      'Custom sentences lost at launch',
    );
    await until(() => private.length == roleIds.length + 1);
    int actor(String role) =>
        private.keys.firstWhere((i) => private[i]!['role'] == role);
    host.startNight();
    host.callNight('metamorph');
    await until(() => private.values.any((p) => p['ability'] is Map));
    final meta = actor('metamorph'), seer = actor('seer');
    clients[meta].gameAction(
      'metamorph.peek',
      (host.snapshot['game'] as Map)['phase_revision'] as int,
      targets: [ids[meta]!, ids[seer]!],
    );
    await until(() => private[meta]?['variant_result'] != null);
    clients[meta].gameAction(
      'metamorph.swap',
      (host.snapshot['game'] as Map)['phase_revision'] as int,
      targets: [ids[meta]!, ids[seer]!],
    );
    await until(
      () =>
          private[meta]?['role'] == 'seer' &&
          private[seer]?['role'] == 'metamorph',
    );
    check(
      (host.snapshot['assignments'] as Map)[ids[meta]] == 'seer',
      'MDJ role map stale',
    );
    check(private[meta]!['role_notice'] != null, 'Missing private role notice');
    host.advanceNight();
    host.callNight('cupid');
    final cupid = actor('cupid'),
        wolf = actor('werewolf'),
        village = actor('villager');
    await until(() => private[cupid]?['can_act'] == true);
    clients[cupid].gameAction(
      'cupid.link',
      (host.snapshot['game'] as Map)['phase_revision'] as int,
      targets: [ids[wolf]!, ids[village]!],
    );
    await until(() => private[wolf]?['lover'] == ids[village]);
    check(private[meta]?['lover'] == null, 'Lovers leaked to other role');
    host.advanceNight();
    host.callNight('guardian');
    final guard = actor('guardian');
    await until(() => private[guard]?['can_act'] == true);
    clients[guard].gameAction(
      'guardian.protect',
      (host.snapshot['game'] as Map)['phase_revision'] as int,
      targets: [ids[village]!],
    );
    await until(
      () => (host.snapshot['game_host'] as Map)['protected'] == ids[village],
    );
    host.advanceNight();
    // Bond and Elder calls must precede the pack, even when their powers pass.
    for (final call in ['sisters', 'lovers', 'elder_watch']) {
      host.callNight(call);
      host.advanceNight();
    }
    host.callNight('sulfuron');
    final sulfuron = actor('sulfuron');
    await until(() => private[sulfuron]?['can_act'] == true);
    clients[sulfuron].gameAction(
      'sulfuron.reveal',
      (host.snapshot['game'] as Map)['phase_revision'] as int,
      targets: [],
    );
    await until(
      () => ((host.snapshot['game'] as Map)['sulfuron_events'] as List)
          .isNotEmpty,
    );
    final publicTrap =
        ((host.snapshot['game'] as Map)['sulfuron_events'] as List).last as Map;
    check(
      !publicTrap.containsKey('actor') && !publicTrap.containsKey('true_role'),
      'Sulfuron identity leaked',
    );
    check(
      !private[wolf]!.containsKey('sulfuron_lives'),
      'Sulfuron charges leaked to pack',
    );
    host.advanceNight();
    host.callNight('wolves');
    await until(
      () =>
          private[wolf]?['phase_revision'] ==
          (host.snapshot['game'] as Map)['phase_revision'],
    );
    for (final role in wolfRoleIds) {
      final i = actor(role);
      check(private[i]!['is_pack'] == true, 'Predator excluded from pack');
      check((private[i]!['pack'] as List).length == 4, 'Incomplete pack');
    }
    check(!leak, 'Private state leaked on public transport');
    print(
      'Network OK: all roles including Sulfuron, private exchanges, bonds, guardian and all wolf variants.',
    );
  } finally {
    for (final sub in subscriptions) {
      await sub.cancel();
    }
    for (final client in clients) {
      await client.dispose();
    }
    await host.dispose();
  }
}
