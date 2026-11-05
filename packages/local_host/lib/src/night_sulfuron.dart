part of 'night_game.dart';

class _SulfuronState {
  final souls = <String, int>{}, bluffNight = <String, int>{};
  final survivedVote = <String>{};
  final stakes = <String, ({String target, int vote})>{};
  final burnVotes = <String, int>{};
  final revengeVoters = <String, List<String>>{};
  final revengeTarget = <String, String>{};
  final publicEvents = <Map<String, dynamic>>[];
  final privateEvents = <String, List<Map<String, dynamic>>>{};
  int sequence = 0;
}

extension _SulfuronRole on NightGame {
  String _sulfuronKey(String id) => _cardTokens[id] ?? 'card:$id';
  int _sulfuronLives(String id) => _sulfuron.souls[_sulfuronKey(id)] ?? 0;
  String? _sulfuronOwner(String key) => alive
      .where((id) => roles[id] == 'sulfuron' && _sulfuronKey(id) == key)
      .firstOrNull;

  void _sulfuronEvent(Map<String, dynamic> event, {String? privateFor}) {
    final item = <String, dynamic>{
      'id': 'sulfuron-${++_sulfuron.sequence}',
      'night': night,
      ...event,
    };
    final events = privateFor == null
        ? _sulfuron.publicEvents
        : _sulfuron.privateEvents.putIfAbsent(
            _sulfuronKey(privateFor),
            () => [],
          );
    events.add(item);
    if (events.length > 32) events.removeAt(0);
  }

  void _publishSulfuronCard(
    String actor,
    String target,
    String role,
    String power,
  ) {
    _sulfuronEvent({
      'kind': 'revelation',
      'player': target,
      'role': role,
      'edition': editionOf(target),
      'power': power,
      'text': power == 'bluff'
          ? 'Vous serez désorientés, mais vous ne me trouverez pas.'
          : power == 'revenge'
          ? 'Sulfuron révèle l’un de ses accusateurs.'
          : 'Un petit mouton conduit à l’abattoir… héhéhé !',
    });
    _log('effect', {
      'effect': 'sulfuron_' + power,
      'actor': actor,
      'target': target,
      'announced_role': role,
      'true_role': roles[target],
    });
  }

  void _openSulfuronCall() {
    for (final id in alive.where((p) => roles[p] == 'sulfuron').toList()) {
      final key = _sulfuronKey(id);
      final eligible = (_sulfuron.revengeVoters[key] ?? [])
          .where(alive.contains)
          .toList();
      if (eligible.isNotEmpty) {
        final chosen = _sulfuron.revengeTarget[key];
        final target = eligible.contains(chosen)
            ? chosen!
            : eligible[_chanceDraw(eligible.length)];
        _publishSulfuronCard(id, target, roles[target]!, 'revenge');
      }
      _sulfuron.revengeVoters.remove(key);
      _sulfuron.revengeTarget.remove(key);
    }
  }

  List<Map<String, dynamic>> _sulfuronAbilities(String id) {
    if (roles[id] != 'sulfuron' || !alive.contains(id) || !_powerEnabled(id))
      return [];
    final key = _sulfuronKey(id);
    final revenge = (_sulfuron.revengeVoters[key] ?? [])
        .where(alive.contains)
        .toList();
    if (phase == 'vote_result' &&
        revenge.isNotEmpty &&
        !_sulfuron.revengeTarget.containsKey(key)) {
      return [
        _expandedChoice(
          'sulfuron.mark',
          'Marquer un accusateur · révélation à mon prochain appel',
          revenge,
          1,
        ),
      ];
    }
    if (phase != 'sulfuron' ||
        _done(id) ||
        night - (_sulfuron.bluffNight[key] ?? -2) < 2)
      return [];
    final others = alive.where((p) => p != id).toList();
    return others.isEmpty
        ? []
        : [
            _expandedChoice(
              'sulfuron.bluff',
              'Le Bluff · rôle presque toujours faux · une nuit sur deux',
              others,
              1,
            ),
          ];
  }

  bool _actSulfuron(String id, Map<String, dynamic> action) {
    if (roles[id] != 'sulfuron' || !alive.contains(id) || !_powerEnabled(id))
      return false;
    final key = _sulfuronKey(id);
    if (action['action'] == 'sulfuron.mark') {
      final ability = _sulfuronAbilities(
        id,
      ).where((p) => p['action'] == 'sulfuron.mark').firstOrNull;
      if (ability == null) return false;
      _sulfuron.revengeTarget[key] = _variantTargets(
        action,
        (ability['targets'] as List).cast<String>(),
        1,
      ).single;
      _notice(
        id,
        'Votre accusateur est marqué. Sa carte sera révélée à votre prochain appel.',
      );
      return true;
    }
    if (phase != 'sulfuron' || _done(id)) return false;
    final command = action['action'];
    if (command != 'sulfuron.bluff' && command != 'sulfuron.reveal')
      return false;
    final others = alive.where((p) => p != id).toList();
    if (others.isEmpty) throw StateError('Aucune cible vivante disponible.');
    late final String target, announced;
    if (command == 'sulfuron.bluff') {
      if (night - (_sulfuron.bluffNight[key] ?? -2) < 2)
        throw StateError('Le Bluff n’est disponible qu’une nuit sur deux.');
      target = _variantTargets(action, others, 1).single;
      final truth = _chanceDraw(100) < 10;
      final falseRoles = roleIds
          .where((r) => r != roles[target] && r != 'sulfuron')
          .toList();
      announced = truth
          ? roles[target]!
          : falseRoles[_chanceDraw(falseRoles.length)];
      _sulfuron.bluffNight[key] = night;
    } else {
      _variantTargets(action, const [], 0);
      target = others[_chanceDraw(others.length)];
      announced = roles[target]!;
      _sulfuron.stakes[key] = (target: target, vote: _expanded.voteRounds + 1);
    }
    _sulfuron.burnVotes[target] = _expanded.voteRounds + 1;
    _publishSulfuronCard(
      id,
      target,
      announced,
      command == 'sulfuron.bluff' ? 'bluff' : 'reveal',
    );
    _markDone(id);
    return true;
  }

  bool _sulfuronPreventsDeath(String id, String cause) {
    if (roles[id] != 'sulfuron' || _sulfuronLives(id) == 0) return false;
    final key = _sulfuronKey(id);
    final vote =
        cause == 'vote' &&
        editionOf(id) != 'classic' &&
        !_sulfuron.survivedVote.contains(key);
    if (cause != 'night' && !vote) return false;
    _sulfuron.souls[key] = _sulfuronLives(id) - 1;
    if (vote) {
      _sulfuron.survivedVote.add(key);
      _voteSummary?['resurrected'] = id;
      if (editionOf(id) == 'horror') {
        _sulfuron.revengeVoters[key] = _votes.entries
            .where((e) => e.value == id && e.key != id && alive.contains(e.key))
            .map((e) => e.key)
            .toList();
      }
      _sulfuronEvent({
        'kind': 'resurrection',
        'player': id,
        if (revealOnDeath) 'role': 'sulfuron',
        'edition': editionOf(id),
        'cause': 'vote',
        'text': 'Une vie volée permet à Sulfuron de revenir après la sentence.',
      });
    }
    _sulfuronEvent({
      'kind': 'revived',
      'player': id,
      'cause': cause,
      'lives': _sulfuronLives(id),
    }, privateFor: id);
    _notice(
      id,
      vote
          ? 'Vous ressuscitez. Un second vote contre vous sera définitif.'
          : 'Une vie volée vous ramène après l’attaque de la meute.',
    );
    _log('effect', {
      'effect': 'sulfuron_revived',
      'actor': id,
      'cause': cause,
      'remaining_lives': _sulfuronLives(id),
    });
    return true;
  }

  void _sulfuronVictimDied(String target, String cause) {
    if (cause != 'vote') return;
    for (final entry in _sulfuron.stakes.entries.toList()) {
      if (entry.value.target != target ||
          entry.value.vote != _expanded.voteRounds)
        continue;
      final owner = _sulfuronOwner(entry.key);
      _sulfuron.stakes.remove(entry.key);
      if (owner == null) continue;
      _sulfuron.souls[entry.key] = _sulfuronLives(owner) + 1;
      _sulfuronEvent({
        'kind': 'soul_gained',
        'player': owner,
        'victim': target,
        'lives': _sulfuronLives(owner),
      }, privateFor: owner);
      _notice(
        owner,
        '+1 vie volée. Vous pourrez survivre à une attaque de la meute en ressuscitant.',
      );
      _log('effect', {
        'effect': 'sulfuron_soul_gained',
        'actor': owner,
        'target': target,
      });
    }
  }

  Map<String, dynamic> _sulfuronPrivate(String id) => roles[id] != 'sulfuron'
      ? {}
      : {
          'sulfuron_lives': _sulfuronLives(id),
          'sulfuron_vote_used': _sulfuron.survivedVote.contains(
            _sulfuronKey(id),
          ),
          'sulfuron_bluff_ready':
              night - (_sulfuron.bluffNight[_sulfuronKey(id)] ?? -2) >= 2,
          'sulfuron_events': [
            for (final e
                in _sulfuron.privateEvents[_sulfuronKey(id)] ??
                    <Map<String, dynamic>>[])
              Map.of(e),
          ],
        };
}
