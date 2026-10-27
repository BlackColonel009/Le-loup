import 'dart:async';
import '../lib/local_host.dart';

void check(bool value, String message) {
  if (!value) throw StateError(message);
}

Future<void> until(bool Function() condition, String label) async {
  final end = DateTime.now().add(const Duration(seconds: 20));
  while (!condition()) {
    if (DateTime.now().isAfter(end)) throw StateError('Timeout: $label');
    await Future<void>.delayed(const Duration(milliseconds: 25));
  }
}

/// Creates its own disposable room. No existing account or room is used.
Future<void> main(List<String> args) async {
  if (args.length != 1) throw ArgumentError('Pass the HTTPS API URL.');
  final host = OnlineHost(args.single);
  final clients = <LobbyClient>[];
  final subscriptions = <StreamSubscription>[];
  final private = <int, Map<String, dynamic>>{};
  final rooms = <int, Map<String, dynamic>>{};
  final errors = <int, int>{};
  final joins = <int, int>{};
  String? leaked;
  Map game() => host.snapshot['game'] as Map;
  Map control() => host.snapshot['game_host'] as Map;
  String id(int i) => clients[i].id!;
  int actor(String role) =>
      private.keys.firstWhere((i) => private[i]!['role'] == role);
  int revision() => game()['phase_revision'] as int;
  Future<void> phase(String value) async {
    await until(
      () =>
          host.snapshot['phase'] == value &&
          rooms.length == 20 &&
          rooms.values.every((r) => r['phase'] == value) &&
          private.length == 20 &&
          private.values.every((p) => p['phase_revision'] == revision()),
      value,
    );
    check(leaked == null, leaked ?? 'Secret transport');
  }

  Future<void> call(String value) async {
    await host.command('night.call', {'call': value});
    await phase(value);
  }

  Future<void> advance() => host.command('night.advance').then((_) {});
  Future<void> ability(int i, String action, List<String> targets) async {
    clients[i].gameAction(action, revision(), targets: targets);
    await until(() => private[i]?['ability_submitted'] == true, action);
  }

  Future<void> rejected(
    int i,
    String action, {
    List<String>? targets,
    String? text,
  }) async {
    final before = errors[i] ?? 0;
    clients[i].gameAction(action, revision(), targets: targets, text: text);
    await until(() => (errors[i] ?? 0) == before + 1, 'Reject $action');
  }

  try {
    await host.start(nickname: 'Audit MDJ');
    await host.command('configure', {
      'deck': {for (final role in roleIds) role: role == 'villager' ? 4 : 1},
      'camp_only': false,
      'pack': 'intense',
    });
    final code = host.snapshot['code'] as String;
    for (var i = 0; i < 20; i++) {
      final index = i, client = LobbyClient();
      clients.add(client);
      subscriptions.add(
        client.events.listen((event) {
          if (event['type'] == 'room.joined')
            joins[index] = (joins[index] ?? 0) + 1;
          if (event['type'] == 'game.private') private[index] = event;
          if (event['type'] == 'error')
            errors[index] = (errors[index] ?? 0) + 1;
          if (event['type'] == 'room.snapshot') {
            rooms[index] = event;
            final publicGame = event['game'] as Map?;
            if (event.containsKey('assignments') ||
                event.containsKey('game_host'))
              leaked = 'Host assignments leaked';
            if (publicGame != null) {
              for (final key in [
                'visions',
                'wolf_choices',
                'wolf_messages',
                'protected',
                'lovers',
                'charmed',
                'pending_infections',
                'spotted_girls',
                'night_actions',
              ]) {
                if (publicGame.containsKey(key)) leaked = 'Public secret: $key';
              }
            }
          }
        }),
      );
      await client.connect(
        onlineSocketUri(host.base, code).toString(),
        code,
        'Audit ${i + 1}',
        appearance: i.isEven ? 'male' : 'female',
      );
      await until(() => client.id != null, 'Join');
      client.setReady(true);
    }
    await until(() => host.snapshot['launch_error'] == null, 'Ready');
    await host.command('start');
    await phase('role_reveal');
    check(
      private.values.map((p) => p['role']).toSet().containsAll(roleIds),
      'Missing role',
    );
    check(
      (host.snapshot['players'] as List)
              .map((p) => p['house_slot'])
              .toSet()
              .length ==
          20,
      'House slots',
    );
    print('20 clients / 17 roles / private dealing OK');

    await host.command('night.start', {'seconds': 120});
    await call('metamorph');
    final meta = actor('metamorph'), oldSeer = actor('seer');
    await ability(meta, 'metamorph.swap', [id(meta), id(oldSeer)]);
    await until(
      () =>
          private[meta]?['role'] == 'seer' &&
          private[oldSeer]?['role'] == 'metamorph',
      'Swap',
    );
    await advance();
    final villagers = private.keys
        .where((i) => private[i]!['role'] == 'villager')
        .toList();
    final protected = villagers[0],
        lover = villagers[1],
        victim = villagers[2],
        spare = villagers[3];
    final hunter = actor('hunter'), guard = actor('guardian');
    await call('cupid');
    await ability(actor('cupid'), 'cupid.link', [id(hunter), id(lover)]);
    await until(
      () =>
          private[hunter]?['lover'] == id(lover) &&
          private[lover]?['lover'] == id(hunter),
      'Private lover notifications',
    );
    check(private[hunter]?['lover'] == id(lover), 'Lover notification');
    await advance();
    await call('guardian');
    await ability(guard, 'guardian.protect', [id(protected)]);
    await until(
      () => private[protected]?['guardian_protected_id'] == id(protected),
      'Private guardian notification',
    );
    check(
      private[protected]?['guardian_protected_id'] == id(protected),
      'Guardian recipient',
    );
    check(
      private[actor('werewolf')]?['guardian_protected_id'] == null,
      'Guardian secret leaked',
    );
    await advance();
    await call('seer');
    clients[meta].gameAction(
      'seer.inspect',
      revision(),
      target: id(actor('alpha_wolf')),
    );
    await until(() => private[meta]?['vision'] != null, 'Vision');
    check(
      (private[meta]!['vision'] as Map)['value'] == 'alpha_wolf',
      'Wrong vision',
    );
    await advance();
    await call('wolves');
    final wolves = private.keys
        .where((i) => private[i]!['is_pack'] == true)
        .toList();
    clients[wolves.first].gameAction(
      'wolves.chat',
      revision(),
      text: 'Audit secret de la meute',
    );
    await until(
      () =>
          wolves.every((i) => (private[i]?['messages'] as List?)?.length == 1),
      'Wolf chat',
    );
    check(
      private.entries
          .where((e) => !wolves.contains(e.key))
          .every((e) => !e.value.containsKey('messages')),
      'Wolf messages leaked',
    );
    await ability(actor('little_girl'), 'little_girl.peek', []);
    check(
      private[actor('little_girl')]?['peek_message'] ==
          'Audit secret de la meute',
      'Anonymous peek',
    );
    for (final i in wolves)
      clients[i].gameAction('wolves.choose', revision(), target: id(hunter));
    await until(
      () => (control()['wolf_choices'] as Map).length == wolves.length,
      'Pack choices',
    );
    await advance();
    await call('alpha');
    await ability(actor('alpha_wolf'), 'alpha.choose', [id(victim)]);
    await advance();
    await call('infection');
    await ability(actor('wolf_father'), 'infection.convert', [id(hunter)]);
    await advance();
    await call('witch');
    final witch = actor('witch');
    clients[witch].gameAction(
      'witch.potions',
      revision(),
      save: true,
      kill: id(victim),
    );
    await until(() => private[witch]?['submitted'] == true, 'Potions');
    await advance();
    await call('piper');
    await ability(actor('piper'), 'piper.charm', [id(protected), id(spare)]);
    await advance();
    await host.command('night.finish');
    await phase('dawn');
    check(
      (game()['alive_ids'] as List).contains(id(hunter)),
      'Life potion failed',
    );
    check(
      !(game()['alive_ids'] as List).contains(id(victim)),
      'Night death missing',
    );
    check(
      (control()['pending_infections'] as Map).isEmpty,
      'Life potion did not cancel infection',
    );
    await advance();
    await phase('day');
    print(
      'Night roles / private wolf chat / protection / potions / infection / charm OK',
    );

    clients[protected].gameAction(
      'day.chat',
      revision(),
      text: 'Audit débat du village',
    );
    await until(
      () => rooms.values.every(
        (r) => ((r['game'] as Map)['day_messages'] as List).length == 1,
      ),
      'Day chat',
    );
    await rejected(victim, 'day.chat', text: 'Interdit au spectateur');
    await host.command('day.chat', {'open': false});
    await rejected(spare, 'day.chat', text: 'Interdit par le MDJ');
    await host.command('day.chat', {'open': true});
    await host.command('vote.start', {'seconds': 120});
    await phase('voting');
    final living = game()['alive_ids'] as List;
    for (var i = 0; i < clients.length; i++) {
      if (living.contains(id(i)))
        clients[i].gameAction('vote.cast', revision(), target: id(hunter));
    }
    await until(() => game()['votes_received'] == living.length, 'All ballots');
    await advance();
    await phase('hunter');
    final wolf = actor('werewolf');
    clients[hunter].gameAction('hunter.shoot', revision(), target: id(wolf));
    await until(() => private[hunter]?['hunter_done'] == true, 'Hunter');
    await advance();
    await phase('vote_result');
    check(
      (game()['alive_ids'] as List).length == 16,
      'Lover/hunter death chain',
    );
    await host.command('sentence.spin');
    await until(
      () => (game()['sentence'] as Map?)?['remaining_ms'] == 0,
      'Sentence completion',
    );
    await host.command('sentence.continue');
    await phase('sleep');
    print(
      'Day chat / spectator restrictions / private votes / lover death / hunter / sentence continuation OK',
    );

    await call('guardian');
    await rejected(guard, 'guardian.protect', targets: [id(protected)]);
    await ability(guard, 'guardian.protect', [id(guard)]);
    await advance();
    await call('white_wolf');
    final alpha = actor('alpha_wolf');
    await ability(actor('white_wolf'), 'white_wolf.choose', [id(alpha)]);
    await advance();
    await call('wolves');
    final remainingWolves = private.keys
        .where(
          (i) => private[i]!['is_pack'] == true && private[i]!['alive'] == true,
        )
        .toList();
    check(
      remainingWolves.every((i) => (private[i]?['messages'] as List).isEmpty),
      'Ephemeral messages persisted',
    );
    final roleBefore = private[protected]!['role'];
    await host.reconnect();
    final previousJoins = joins[protected] ?? 0;
    await clients[protected].reconnect();
    await until(
      () => (joins[protected] ?? 0) > previousJoins,
      'Player rejoined',
    );
    await phase('wolves');
    check(private[protected]!['role'] == roleBefore, 'Reconnect changed role');
    final elder = actor('elder');
    for (final i in remainingWolves)
      clients[i].gameAction('wolves.choose', revision(), target: id(elder));
    await until(
      () => (control()['wolf_choices'] as Map).length == remainingWolves.length,
      'Night 2 choices',
    );
    await advance();
    check(
      !(control()['night_actions'] as List).any((a) => a['action'] == 'alpha'),
      'Alpha bonus survived a pack death',
    );
    await host.command('night.finish');
    await phase('dawn');
    check(
      (game()['alive_ids'] as List).contains(id(elder)),
      'Elder first resistance',
    );
    check(
      !(game()['alive_ids'] as List).contains(id(alpha)),
      'White wolf attack',
    );
    await advance();
    await phase('day');
    check(leaked == null, leaked ?? 'Secret check');
    check(
      errors.values.fold<int>(0, (a, b) => a + b) == 3,
      'Unexpected player error',
    );
    print(
      'Night 2 / white wolf / elder / Alpha limit / host and player reconnect / secrecy OK',
    );
    print(
      'FULL ONLINE AUDIT PASSED: 20 clients, 17 roles, two nights and one complete day.',
    );
  } finally {
    for (final sub in subscriptions) await sub.cancel();
    for (final client in clients) await client.dispose();
    await host.dispose();
  }
}
