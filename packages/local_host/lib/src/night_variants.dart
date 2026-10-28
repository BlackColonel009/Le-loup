part of 'night_game.dart';

extension _CardVariants on NightGame {
  bool _variant(String id, String role, String edition) =>
      roles[id] == role && editionOf(id) == edition;
  bool _spent(String id, String power) =>
      _variantSpent.contains('${_cardTokens[id]}:$power');
  void _spend(String id, String power) =>
      _variantSpent.add('${_cardTokens[id]}:$power');
  String _campGroup(String id) =>
      ['village', 'wolves'].contains(_camp(id)) ? _camp(id) : 'solitary';
  bool _roleVeiled(String id) =>
      _veiledUntil.containsKey(id) &&
      (night < _veiledUntil[id]! || night == _veiledUntil[id]! && _atNight);
  bool _guardBlocksPack(String? id) =>
      id != null && id == _extra.protected && _guardMode != 'sacrifice';
  List<String> _variantTargets(
    Map<String, dynamic> action,
    List<String> allowed,
    int count,
  ) {
    final raw = action['targets'];
    if (raw is! List ||
        raw.length != count ||
        raw.any((v) => v is! String || !allowed.contains(v)) ||
        raw.toSet().length != count) {
      throw ArgumentError(
        'Choisissez $count joueur(s) distinct(s) autorisé(s).',
      );
    }
    return raw.cast<String>();
  }

  List<Map<String, dynamic>> _variantAbilities(String id) {
    if (!alive.contains(id) || !_powerEnabled(id)) return [];
    Map<String, dynamic> ability(
      String action,
      String label,
      List<String> targets,
      int count,
    ) => {
      'action': action,
      'label': label,
      'targets': targets,
      'min': count,
      'max': count,
      'can_pass': false,
    };
    final others = alive.where((p) => p != id).toList();
    if (phase == 'seer' && !_visions.containsKey(id)) {
      if (_variant(id, 'seer', 'intense'))
        return [
          ability(
            'seer.compare',
            'Comparer deux camps (remplace la vision)',
            others,
            2,
          ),
        ];
      if (_variant(id, 'seer', 'horror') && !_spent(id, 'double_vision'))
        return [
          ability(
            'seer.double',
            'Deux visions interdites · une fois',
            others,
            2,
          ),
        ];
    }
    if (phase == 'guardian' && roles[id] == 'guardian' && !_done(id)) {
      final targets = others
          .where(
            (p) =>
                _extra.guardNight[id] != night - 1 ||
                _extra.guardPrevious[id] != p,
          )
          .toList();
      if (_variant(id, 'guardian', 'intense') && !_spent(id, 'ward'))
        return [
          ability(
            'guardian.ward',
            'Protection renforcée contre le poison · une fois',
            targets,
            1,
          ),
        ];
      if (_variant(id, 'guardian', 'horror') && !_spent(id, 'sacrifice'))
        return [
          ability(
            'guardian.sacrifice',
            'Offrir ma vie pour cette cible · une fois',
            targets,
            1,
          ),
        ];
    }
    if (phase == 'wolves' && roles[id] == 'werewolf' && _isWolf(id)) {
      if (_variant(id, 'werewolf', 'intense') && !_spent(id, 'scent'))
        return [
          ability(
            'wolves.scent',
            'Flairer une protection · une fois',
            others.where((p) => !_isWolf(p)).toList(),
            1,
          ),
        ];
      if (_variant(id, 'werewolf', 'horror') &&
          !_spent(id, 'veil') &&
          !_veilRequests.contains(id))
        return [
          ability('wolves.veil', 'Voiler la victime commune · une fois', [], 0),
        ];
    }
    return [];
  }

  bool _actVariants(String id, Map<String, dynamic> action) {
    if (!_powerEnabled(id)) return false;
    if (phase == 'metamorph' &&
        _variant(id, 'metamorph', 'intense') &&
        !_extra.metamorphUsed &&
        !_done(id) &&
        action['action'] == 'metamorph.peek') {
      final chosen = _variantTargets(action, alive.toList(), 2);
      _metaPeek[id] = chosen;
      _extra.metamorphUsed = true;
      _variantInfo[id] = {
        'kind': 'camps',
        'camps': {for (final p in chosen) p: _campGroup(p)},
      };
      return true;
    }
    final ability = _variantAbilities(
      id,
    ).where((a) => a['action'] == action['action']).firstOrNull;
    if (ability == null) return false;
    final chosen = _variantTargets(
      action,
      (ability['targets'] as List).cast<String>(),
      ability['min'] as int,
    );
    switch (action['action']) {
      case 'seer.compare':
        _visions[id] = {
          'target': chosen[0],
          'kind': 'comparison',
          'value': _campGroup(chosen[0]) == _campGroup(chosen[1])
              ? 'same'
              : 'different',
        };
        _variantInfo[id] = {
          'kind': 'comparison',
          'targets': chosen,
          'same_camp': _campGroup(chosen[0]) == _campGroup(chosen[1]),
        };
      case 'seer.double':
        _spend(id, 'double_vision');
        final results = [
          for (final p in chosen)
            {
              'target': p,
              'kind': campOnly ? 'camp' : 'role',
              'value': campOnly ? _campGroup(p) : roles[p]!,
            },
        ];
        _visions[id] = Map<String, String>.from(results.first);
        _variantInfo[id] = {'kind': 'visions', 'visions': results};
        for (final p in chosen) {
          _notice(
            p,
            'Une vision interdite vous a sondé cette nuit, sans révéler son auteur.',
          );
        }
      case 'guardian.ward':
      case 'guardian.sacrifice':
        final power = action['action'] == 'guardian.ward'
            ? 'ward'
            : 'sacrifice';
        _spend(id, power);
        _guardMode = power;
        _guardActor = id;
        _extra.protected = chosen.single;
        _extra.guardPrevious[id] = chosen.single;
        _extra.guardNight[id] = night;
        _markDone(id);
      case 'wolves.scent':
        _spend(id, 'scent');
        final p = chosen.single;
        final protected =
            p == _extra.protected ||
            roles[p] == 'elder' &&
                _powerEnabled(p) &&
                !_extra.elderHit.contains(p);
        _variantInfo[id] = {
          'kind': 'scent',
          'target': p,
          'protected': protected,
        };
      case 'wolves.veil':
        _veilRequests.add(id);
    }
    return true;
  }

  void _resetVariantsNight() {
    _deathOrigins.clear();
    _variantInfo.clear();
    _metaPeek.clear();
    _veilRequests.clear();
    _guardMode = 'normal';
    _guardActor = null;
  }

  void _resolveVariantProtection(Map<String, String> victims) {
    final target = _extra.protected;
    if (_guardMode == 'ward' && target != null && victims[target] == 'poison') {
      victims.remove(target);
      _log('effect', {
        'effect': 'poison_blocked',
        'target': target,
        'actor': _guardActor,
      });
    }
    if (_guardMode == 'sacrifice' &&
        target != null &&
        _guardActor != null &&
        alive.contains(_guardActor) &&
        victims.containsKey(target)) {
      final sourceCause = victims.remove(target)!;
      _deathOrigins[_guardActor!] = {
        'source_cause': sourceCause,
        'redirected_from': target,
      };
      victims[_guardActor!] = 'sacrifice';
      _log('effect', {
        'effect': 'guardian_sacrifice',
        'target': target,
        'actor': _guardActor,
      });
    }
    if (_attack != null && victims[_attack] == 'night') {
      final actor = _veilRequests
          .where((p) => alive.contains(p) && !_spent(p, 'veil'))
          .firstOrNull;
      if (actor != null) {
        _spend(actor, 'veil');
        _veiledUntil[_attack!] = night + 1;
        _log('effect', {
          'effect': 'role_veiled',
          'target': _attack,
          'actor': actor,
          'until_night': night + 1,
        });
      }
    }
  }

  void _swapCardMemory(String a, String b) {
    void swapMap(Map map) {
      final hasA = map.containsKey(a),
          hasB = map.containsKey(b),
          va = map[a],
          vb = map[b];
      map.remove(a);
      map.remove(b);
      if (hasB) map[a] = vb;
      if (hasA) map[b] = va;
    }

    void swapSet(Set<String> values) {
      final va = values.remove(a), vb = values.remove(b);
      if (vb) values.add(a);
      if (va) values.add(b);
    }

    swapMap(_editions);
    swapMap(_cardTokens);
    for (final set in [
      _lifeSpent,
      _deathSpent,
      _extra.elderHit,
      _extra.infectionSpent,
      _recognizedSisters,
    ]) {
      swapSet(set);
    }
    swapMap(_extra.guardPrevious);
    swapMap(_extra.guardNight);
  }
}
