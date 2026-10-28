import 'package:flutter_test/flutter_test.dart';
import 'package:local_host/local_host.dart';

NightGame make({
  Map<String, String> roles = const {},
  Map<String, String> editions = const {},
}) => NightGame({
  'w': 'werewolf',
  'a': 'villager',
  'b': 'villager',
  'c': 'villager',
  'd': 'villager',
  ...roles,
}, editions: editions);
void act(
  NightGame g,
  String id,
  String command, {
  String? target,
  List<String>? targets,
  bool save = false,
  String? kill,
}) => g.act(id, {
  'phase_revision': g.revision,
  'action': command,
  'target': target,
  'targets': targets,
  'save': save,
  'kill': kill,
});
void nextNight(NightGame g) {
  if (g.phase == 'sleep') g.finishNight();
  if (g.phase == 'dawn') g.advance();
  expect(g.phase, 'day');
  g.startVote();
  for (final id in g.alive.toList()) {
    act(g, id, 'vote.cast');
  }
  g.advance();
  expect(g.phase, 'vote_result');
  g.startNight();
}

void wolves(NightGame g, String? target) {
  g.callNight('wolves');
  if (target != null) {
    for (final id
        in g.alive
            .where((id) => g.privateState(id)['is_pack'] == true)
            .toList()) {
      act(g, id, 'wolves.choose', target: target);
    }
  }
  g.advance();
}

void main() {
  test(
    'Voyante Intense compare deux camps sans révéler leurs rôles ni laisser une seconde action',
    () {
      final g = make(roles: {'s': 'seer'}, editions: {'s': 'intense'});
      g.startNight();
      g.callNight('seer');
      act(g, 's', 'seer.compare', targets: ['a', 'w']);
      expect(g.privateState('s')['variant_result']['same_camp'], isFalse);
      expect(
        g.privateState('s')['variant_result'].toString(),
        isNot(contains('werewolf')),
      );
      expect(g.privateState('a').containsKey('variant_result'), isFalse);
      expect(() => act(g, 's', 'seer.inspect', target: 'w'), throwsStateError);
      expect(
        () => act(g, 'a', 'seer.compare', targets: ['b', 'w']),
        throwsStateError,
      );
    },
  );
  test(
    'Une vision normale reste possible en Intense et interdit ensuite la comparaison',
    () {
      final g = make(roles: {'s': 'seer'}, editions: {'s': 'intense'});
      g.startNight();
      g.callNight('seer');
      act(g, 's', 'seer.inspect', target: 'w');
      expect(g.privateState('s')['vision']['value'], 'werewolf');
      expect(
        () => act(g, 's', 'seer.compare', targets: ['a', 'b']),
        throwsStateError,
      );
    },
  );
  test('Oracle : deux visions privées, cibles averties, charge unique', () {
    final g = make(roles: {'s': 'seer'}, editions: {'s': 'horror'});
    g.startNight();
    g.callNight('seer');
    expect(
      () => act(g, 's', 'seer.double', targets: ['a', 'a']),
      throwsArgumentError,
    );
    act(g, 's', 'seer.double', targets: ['a', 'w']);
    expect(g.privateState('s')['variant_result']['visions'], hasLength(2));
    expect(g.privateState('a')['role_notice'], contains('sondé'));
    expect(g.privateState('w')['role_notice'], isNot(contains('s :')));
    expect(g.privateState('b').containsKey('variant_result'), isFalse);
    g.advance();
    nextNight(g);
    g.callNight('seer');
    expect(g.privateState('s')['variant_abilities'], isEmpty);
    act(g, 's', 'seer.inspect', target: 'w');
  });
  test('Le réglage camp uniquement s’applique aux deux visions', () {
    final g = NightGame(
      {'s': 'seer', 'w': 'werewolf', 'a': 'villager', 'b': 'villager'},
      editions: {'s': 'horror'},
      campOnly: true,
    );
    g.startNight();
    g.callNight('seer');
    act(g, 's', 'seer.double', targets: ['a', 'w']);
    final results = g.privateState('s')['variant_result']['visions'] as List;
    expect(results.map((r) => r['value']), ['village', 'wolves']);
  });
  test(
    'Métamorphe Intense : camps privés puis échange limité aux cartes consultées',
    () {
      final g = make(
        roles: {'m': 'metamorph'},
        editions: {'m': 'intense', 'w': 'horror'},
      );
      g.startNight();
      g.callNight('metamorph');
      act(g, 'm', 'metamorph.peek', targets: ['a', 'w']);
      expect(g.privateState('m')['variant_result']['camps'], {
        'a': 'village',
        'w': 'wolves',
      });
      expect(g.privateState('a').containsKey('variant_result'), isFalse);
      expect(
        () => act(g, 'm', 'metamorph.swap', targets: ['a', 'b']),
        throwsArgumentError,
      );
      act(g, 'm', 'metamorph.swap', targets: ['a', 'w']);
      expect(g.roles['a'], 'werewolf');
      expect(g.editionOf('a'), 'horror');
      expect(g.editionOf('w'), 'classic');
      expect(g.privateState('a')['role_notice'], contains('échangée'));
    },
  );
  test(
    'Métamorphe Intense : renoncer après consultation consomme bien l’utilisation',
    () {
      final g = make(roles: {'m': 'metamorph'}, editions: {'m': 'intense'});
      g.startNight();
      g.callNight('metamorph');
      act(g, 'm', 'metamorph.peek', targets: ['a', 'w']);
      act(g, 'm', 'night.pass');
      g.advance();
      nextNight(g);
      expect(() => g.callNight('metamorph'), throwsStateError);
    },
  );
  test('Voleur d’âmes attend une nuit et agit avant les autres pouvoirs', () {
    final g = make(roles: {'m': 'metamorph'}, editions: {'m': 'horror'});
    g.startNight();
    g.callNight('metamorph');
    act(g, 'm', 'night.pass');
    g.advance();
    nextNight(g);
    expect(() => g.callNight('wolves'), throwsStateError);
    g.callNight('metamorph');
    act(g, 'm', 'metamorph.swap', targets: ['a', 'w']);
    expect(g.roles['a'], 'werewolf');
  });
  test(
    'Un échange tardif ne recrée pas la potion consommée et déplace l’édition',
    () {
      final g = make(
        roles: {'m': 'metamorph', 't': 'witch'},
        editions: {'m': 'horror', 't': 'intense'},
      );
      g.startNight();
      g.callNight('metamorph');
      act(g, 'm', 'night.pass');
      g.advance();
      wolves(g, null);
      g.callNight('witch');
      act(g, 't', 'witch.potions', kill: 'b');
      g.advance();
      nextNight(g);
      g.callNight('metamorph');
      act(g, 'm', 'metamorph.swap', targets: ['t', 'a']);
      expect(g.roles['a'], 'witch');
      expect(g.editionOf('a'), 'intense');
      expect(g.privateState('a')['death_available'], isFalse);
    },
  );
  test(
    'Gardien royal : poison arrêté, pas d’auto-renforcement, charge unique après échange',
    () {
      final g = make(
        roles: {'g': 'guardian', 't': 'witch', 'm': 'metamorph'},
        editions: {'g': 'intense', 'm': 'horror'},
      );
      g.startNight();
      g.callNight('metamorph');
      act(g, 'm', 'night.pass');
      g.advance();
      g.callNight('guardian');
      expect(
        () => act(g, 'g', 'guardian.ward', targets: ['g']),
        throwsArgumentError,
      );
      act(g, 'g', 'guardian.ward', targets: ['a']);
      g.advance();
      wolves(g, null);
      g.callNight('witch');
      act(g, 't', 'witch.potions', kill: 'a');
      g.advance();
      g.finishNight();
      expect(g.alive, contains('a'));
      nextNight(g);
      g.callNight('metamorph');
      act(g, 'm', 'metamorph.swap', targets: ['g', 'b']);
      g.advance();
      g.callNight('guardian');
      expect(g.privateState('b')['variant_abilities'], isEmpty);
      expect(
        (g.privateState('b')['ability']['targets'] as List),
        isNot(contains('a')),
      );
    },
  );
  test(
    'Gardien sacrificiel : poison et attaque commune redirigés sur le Gardien',
    () {
      for (final poison in [false, true]) {
        final g = make(
          roles: {'g': 'guardian', if (poison) 't': 'witch'},
          editions: {'g': 'horror'},
        );
        g.startNight();
        g.callNight('guardian');
        act(g, 'g', 'guardian.sacrifice', targets: ['a']);
        g.advance();
        wolves(g, poison ? null : 'a');
        if (poison) {
          g.callNight('witch');
          act(g, 't', 'witch.potions', kill: 'a');
          g.advance();
        }
        g.finishNight();
        expect(g.alive, contains('a'));
        expect(g.alive, isNot(contains('g')));
        expect(
          (g.publicState['death_events'] as List).single['cause'],
          'sacrifice',
        );
      }
    },
  );
  test('La protection normale Classique ne bloque toujours pas le poison', () {
    final g = make(roles: {'g': 'guardian', 't': 'witch'});
    g.startNight();
    g.callNight('guardian');
    act(g, 'g', 'guardian.protect', targets: ['a']);
    g.advance();
    wolves(g, null);
    g.callNight('witch');
    act(g, 't', 'witch.potions', kill: 'a');
    g.advance();
    g.finishNight();
    expect(g.alive, isNot(contains('a')));
  });
  test('Traqueur : flair privé et unique, vote de chasse conservé', () {
    final g = make(roles: {'g': 'guardian'}, editions: {'w': 'intense'});
    g.startNight();
    g.callNight('guardian');
    act(g, 'g', 'guardian.protect', targets: ['a']);
    g.advance();
    g.callNight('wolves');
    act(g, 'w', 'wolves.scent', targets: ['a']);
    expect(g.privateState('w')['variant_result']['protected'], isTrue);
    expect(g.privateState('g').containsKey('variant_result'), isFalse);
    expect(() => act(g, 'w', 'wolves.scent', targets: ['b']), throwsStateError);
    act(g, 'w', 'wolves.choose', target: 'b');
    g.advance();
    g.finishNight();
    expect(g.alive, isNot(contains('b')));
  });
  test(
    'Deux loups de variantes distinctes gardent des pouvoirs indépendants',
    () {
      final g = make(
        roles: {'w2': 'werewolf'},
        editions: {'w': 'intense', 'w2': 'horror'},
      );
      g.startNight();
      g.callNight('wolves');
      expect(
        (g.privateState('w')['variant_abilities'] as List).single['action'],
        'wolves.scent',
      );
      expect(
        (g.privateState('w2')['variant_abilities'] as List).single['action'],
        'wolves.veil',
      );
      expect(() => act(g, 'w', 'wolves.veil', targets: []), throwsStateError);
    },
  );
  test(
    'Voile : charge préservée si attaque empêchée, secret jusqu’au réveil suivant',
    () {
      final g = make(roles: {'g': 'guardian'}, editions: {'w': 'horror'});
      g.startNight();
      g.callNight('guardian');
      act(g, 'g', 'guardian.protect', targets: ['a']);
      g.advance();
      g.callNight('wolves');
      act(g, 'w', 'wolves.veil', targets: []);
      act(g, 'w', 'wolves.choose', target: 'a');
      g.advance();
      g.finishNight();
      expect(g.alive, contains('a'));
      nextNight(g);
      g.callNight('guardian');
      g.advance();
      g.callNight('wolves');
      expect(g.privateState('w')['variant_abilities'], isNotEmpty);
      act(g, 'w', 'wolves.veil', targets: []);
      act(g, 'w', 'wolves.choose', target: 'a');
      g.advance();
      g.finishNight();
      final death = (g.publicState['death_events'] as List).single;
      expect(death['veiled'], isTrue);
      expect(death.containsKey('role'), isFalse);
      expect(
        (g.publicState['revealed_roles'] as Map).containsKey('a'),
        isFalse,
      );
      nextNight(g);
      expect(
        (g.publicState['death_events'] as List).single.containsKey('role'),
        isFalse,
      );
      g.finishNight();
      expect(
        (g.publicState['death_events'] as List).single['role'],
        'villager',
      );
      expect(g.publicState['unveiled_roles']['a'], 'villager');
    },
  );
}
