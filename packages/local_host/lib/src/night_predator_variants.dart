part of 'night_game.dart';

extension _PredatorVariants on NightGame {
  bool _alphaCanAttack(String id) =>
      roles[id] == 'alpha_wolf' &&
      (!_extra.packBroken ||
          editionOf(id) == 'intense' && !_spent(id, 'last_hunt'));
  bool _whiteCanAttack(String id) =>
      roles[id] == 'white_wolf' &&
      (night.isEven || _expanded.whiteDeferred[id] == night);
  List<String> _dormantTargets(String id) => [
    for (final entry in _expanded.dormantOwners.entries)
      if (entry.value == _cardTokens[id] &&
          alive.contains(entry.key) &&
          _extra.infections.containsKey(entry.key))
        entry.key,
  ];

  List<Map<String, dynamic>> _predatorAbilities(String id) {
    if (!alive.contains(id) || !_powerEnabled(id) || _done(id)) return [];
    final others = alive.where((p) => p != id).toList();
    if (phase == 'alpha' &&
        _alphaCanAttack(id) &&
        _attack != null &&
        editionOf(id) == 'horror' &&
        !_spent(id, 'terror')) {
      return [
        _expandedChoice(
          'alpha.terror',
          'Remplacer la seconde attaque par la terreur · prochain scrutin sans vote',
          others.where((p) => !_isWolf(p) && p != _attack).toList(),
          1,
        ),
      ];
    }
    if (phase == 'white_wolf' && _whiteCanAttack(id)) {
      if (editionOf(id) == 'intense' &&
          night.isEven &&
          !_spent(id, 'white_delay')) {
        return [
          _expandedChoice(
            'white_wolf.defer',
            'Reporter cette attaque personnelle à la nuit suivante · une fois',
            [],
            0,
          ),
        ];
      }
      if (editionOf(id) == 'horror' && !_spent(id, 'outsider_hunt')) {
        return [
          _expandedChoice(
            'white_wolf.outsider',
            'Chasser hors de la meute · une fois · les loups apprendront qu’un traître chasse',
            others.where((p) => !_isWolf(p)).toList(),
            1,
          ),
        ];
      }
    }
    if (phase == 'infection' && roles[id] == 'wolf_father') {
      final dormant = _dormantTargets(id);
      if (dormant.isNotEmpty)
        return [
          _expandedChoice(
            'infection.activate',
            'Activer mon infection dormante maintenant',
            dormant,
            1,
          ),
        ];
      if (_attack != null && !_extra.infectionSpent.contains(id)) {
        if (editionOf(id) == 'intense')
          return [
            _expandedChoice(
              'infection.immediate',
              'Conversion dès la résolution de cette nuit',
              [_attack!],
              1,
            ),
          ];
        if (editionOf(id) == 'horror')
          return [
            _expandedChoice(
              'infection.dormant',
              'Infection dormante · activation anticipée ou automatique dans deux nuits',
              [_attack!],
              1,
            ),
          ];
      }
    }
    return [];
  }

  bool _actPredatorVariant(String id, Map<String, dynamic> action) {
    final ability = _predatorAbilities(
      id,
    ).where((a) => a['action'] == action['action']).firstOrNull;
    if (ability == null) return false;
    final chosen = _variantTargets(
      action,
      (ability['targets'] as List).cast<String>(),
      ability['min'] as int,
    );
    switch (action['action']) {
      case 'alpha.terror':
        _spend(id, 'terror');
        _expanded.deniedVotes[chosen.single] = night;
        _notice(
          chosen.single,
          'La terreur vous prive du prochain scrutin de condamnation. Vous pouvez toujours discuter.',
        );
      case 'white_wolf.defer':
        _spend(id, 'white_delay');
        _expanded.whiteDeferred[id] = night + 1;
      case 'white_wolf.outsider':
        _spend(id, 'outsider_hunt');
        _extra.whiteAttack = chosen.single;
        for (final wolf in alive.where(_isWolf)) {
          _notice(
            wolf,
            'Un traître chasse parmi la meute cette nuit. Son identité reste inconnue.',
          );
        }
      case 'infection.immediate':
      case 'infection.dormant':
        final target = chosen.single;
        final dormant = action['action'] == 'infection.dormant';
        _extra.infectionSpent.add(id);
        _extra.infectTarget = target;
        _expanded.infectionDue[target] = dormant ? night + 2 : night;
        if (dormant) _expanded.dormantOwners[target] = _cardTokens[id]!;
      case 'infection.activate':
        _extra.infections[chosen.single] = night;
        _applyDueInfections();
    }
    _markDone(id);
    return true;
  }

  void _applyDueInfections() {
    for (final id in _extra.infections.keys.toList()) {
      if (_extra.infections[id]! <= night) {
        if (alive.contains(id)) {
          _extra.infected.add(id);
          final source = _history.reversed
              .where(
                (e) =>
                    e['kind'] == 'action' &&
                    e['action'] == 'infection.convert' &&
                    (e['targets'] as List? ?? [e['target']]).contains(id),
              )
              .firstOrNull;
          _log('effect', {
            'effect': 'infection',
            'target': id,
            'actor': source?['actor'],
          });
          _notice(
            id,
            'Vous rejoignez la meute. Vous conservez votre rôle et ses pouvoirs ; votre camp est désormais Loups-Garous. Une action déjà effectuée ne peut pas être rejouée.',
          );
        }
        _extra.infections.remove(id);
      }
    }
    _expanded.dormantOwners.removeWhere(
      (id, _) => !_extra.infections.containsKey(id),
    );
  }
}
