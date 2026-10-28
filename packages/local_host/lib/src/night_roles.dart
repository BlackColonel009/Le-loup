part of 'night_game.dart';

const _nightCalls = {
  'metamorph': ('metamorph', 'le Métamorphe'),
  'cupid': ('cupid', 'Cupidon'),
  'guardian': ('guardian', 'le Salvateur'),
  'seer': ('seer', 'la Voyante'),
  'wolves': ('pack', 'les Loups-Garous'),
  'alpha': ('alpha_wolf', 'le Grand Méchant Loup'),
  'infection': ('wolf_father', 'le Père des Loups'),
  'witch': ('witch', 'la Sorcière'),
  'white_wolf': ('white_wolf', 'le Loup Blanc'),
  'piper': ('piper', 'le Joueur de Flûte'),
};

class _RoleState {
  final infected = <String>{};
  final infections = <String, int>{};
  final lovers = <String, String>{};
  final charmed = <String>{};
  final gracedIdiots = <String>{};
  final elderHit = <String>{};
  final infectionSpent = <String>{};
  final acted = <String>{};
  final guardPrevious = <String, String>{};
  final guardNight = <String, int>{};
  final peek = <String, String>{};
  final spotted = <String>{};
  final notices = <String, String>{};
  final versions = <String, int>{};
  final hunters = <String>[];
  final winners = <String>[];
  Set<String>? voters;
  int restrictedNight = -1;
  String? protected,
      extraAttack,
      whiteAttack,
      infectTarget,
      scapegoat,
      angelWinner;
  bool metamorphUsed = false,
      cupidUsed = false,
      packBroken = false,
      villagePowersLost = false,
      firstVoteResolved = false;
}

extension _AdditionalRoles on NightGame {
  bool _isWolf(String? id) =>
      id != null &&
      (_extra.infected.contains(id) || wolfRoleIds.contains(_roles[id]));
  String _camp(String id) {
    if (_roles[id] == 'white_wolf' && !_extra.infected.contains(id))
      return 'white_wolf';
    if (_isWolf(id)) return 'wolves';
    return ['piper', 'angel'].contains(_roles[id]) ? _roles[id]! : 'village';
  }

  bool _powerEnabled(String id) =>
      !(_extra.villagePowersLost && _camp(id) == 'village');
  bool _done(String id) => _extra.acted.contains('$phase:$id');
  void _markDone(String id) => _extra.acted.add('$phase:$id');
  void _notice(String id, String message) {
    _extra.notices[id] = message;
    _extra.versions[id] = (_extra.versions[id] ?? 0) + 1;
  }

  Set<String> get _eligibleVoters => alive
      .where(
        (id) =>
            !_extra.gracedIdiots.contains(id) &&
            (_extra.restrictedNight != night || _extra.voters!.contains(id)),
      )
      .toSet();

  bool _callExists(String action) {
    final role = _nightCalls[action]!.$1;
    if (role == 'pack') return alive.any(_isWolf);
    if (!_hasLivingRole(role)) return false;
    return switch (action) {
      'metamorph' => night == 1 && !_extra.metamorphUsed,
      'cupid' => night == 1 && !_extra.cupidUsed,
      'alpha' => !_extra.packBroken,
      'infection' => alive.any(
        (id) =>
            roles[id] == 'wolf_father' && !_extra.infectionSpent.contains(id),
      ),
      'white_wolf' => night.isEven,
      _ => true,
    };
  }

  String? _dependency(String action) {
    if (action != 'metamorph' &&
        _callExists('metamorph') &&
        !_nightCompleted.contains('metamorph')) {
      return 'Terminez ou passez le Métamorphe avant les autres appels.';
    }
    if (!['metamorph', 'cupid'].contains(action) &&
        _callExists('cupid') &&
        !_nightCompleted.contains('cupid')) {
      return 'Terminez ou passez Cupidon avant les autres appels.';
    }
    if (action == 'wolves' &&
        _callExists('guardian') &&
        !_nightCompleted.contains('guardian')) {
      return 'Appelez ou passez le Salvateur avant la chasse.';
    }
    if (['witch', 'alpha', 'infection'].contains(action) &&
        alive.any(_isWolf) &&
        !_nightCompleted.contains('wolves')) {
      return 'Résolvez l’attaque des loups pour connaître la victime.';
    }
    if (action == 'witch') {
      for (final preceding in ['alpha', 'infection']) {
        if (_callExists(preceding) &&
            _attack != null &&
            !_nightCompleted.contains(preceding)) {
          return 'Terminez ou passez ${_nightCalls[preceding]!.$2} avant la Sorcière.';
        }
      }
    }
    if (['alpha', 'infection'].contains(action) && _attack == null)
      return 'Aucune victime de la meute cette nuit.';
    return null;
  }

  List<Map<String, dynamic>> _buildNightActions() => [
    for (final action in _nightCalls.keys)
      if (_callExists(action) || _nightCompleted.contains(action))
        {
          'action': action,
          'label': 'Appeler ${_nightCalls[action]!.$2}',
          'completed': _nightCompleted.contains(action),
          'available':
              phase == 'sleep' &&
              !_nightCompleted.contains(action) &&
              _dependency(action) == null,
          if (!_nightCompleted.contains(action) && _dependency(action) != null)
            'reason': _dependency(action),
        },
  ];

  String _extraAnnouncement() => phase == 'scapegoat'
      ? 'Bouc émissaire, désigne les joueurs qui pourront voter demain.'
      : _nightCalls.containsKey(phase)
      ? '${_nightCalls[phase]!.$2}, réveille-toi. Choisis ton action.'
      : '';
  String _victoryAnnouncement() => switch (winner) {
    'draw' => 'Le village est désert. Partie nulle.',
    'village' => 'Le Village remporte la partie.',
    'wolves' => 'Les Loups-Garous remportent la partie.',
    'white_wolf' =>
      'Le Loup Blanc est le dernier survivant et remporte la partie.',
    'piper' =>
      'Le Joueur de Flûte a charmé tous les autres survivants et remporte la partie.',
    'angel' =>
      'L’Ange a atteint son objectif au premier vote et remporte la partie.',
    'lovers' => 'Les amoureux de camps opposés remportent ensemble la partie.',
    _ => '',
  };

  bool get _mixedLovers {
    if (_extra.lovers.length != 2) return false;
    final pair = _extra.lovers.keys.toList();
    return _camp(pair[0]) != _camp(pair[1]);
  }

  List<String> get _winningPipers => alive
      .where(
        (id) =>
            roles[id] == 'piper' &&
            !_isWolf(id) &&
            alive.every(
              (other) => other == id || _extra.charmed.contains(other),
            ),
      )
      .toList();
  void _resolveVictory() {
    winner = null;
    _extra.winners.clear();
    if (_extra.angelWinner != null) {
      winner = 'angel';
      _extra.winners.add(_extra.angelWinner!);
    } else if (alive.isEmpty) {
      winner = 'draw';
    } else if (_mixedLovers &&
        alive.length == 2 &&
        alive.every(_extra.lovers.containsKey)) {
      winner = 'lovers';
      _extra.winners.addAll(alive);
    } else if (alive.length == 1 && _camp(alive.single) == 'white_wolf') {
      winner = 'white_wolf';
      _extra.winners.add(alive.single);
    } else if (_winningPipers.isNotEmpty) {
      winner = 'piper';
      _extra.winners.addAll(_winningPipers);
    } else {
      final friendly = alive.where((id) => _camp(id) == 'wolves').length;
      final white = alive.any((id) => _camp(id) == 'white_wolf');
      final piper = alive.any((id) => _camp(id) == 'piper');
      if (!alive.any(_isWolf) && !piper) {
        winner = 'village';
        _extra.winners.addAll(roles.keys.where((id) => _camp(id) == 'village'));
      } else if (!white && friendly > 0 && friendly * 2 >= alive.length) {
        winner = 'wolves';
        _extra.winners.addAll(roles.keys.where((id) => _camp(id) == 'wolves'));
      }
    }
  }

  void _startExtraNight() {
    for (final id in _extra.infections.keys.toList()) {
      if (_extra.infections[id]! <= night) {
        if (alive.contains(id)) {
          _extra.infected.add(id);
          _log('effect', {'effect': 'infection', 'target': id});
          _notice(
            id,
            'Vous rejoignez la meute. Vous conservez votre rôle et ses pouvoirs ; votre camp est désormais Loups-Garous.',
          );
        }
        _extra.infections.remove(id);
      }
    }
    _extra.acted.clear();
    _extra.peek.clear();
    _extra.spotted.clear();
    _extra.hunters.clear();
    _extra.protected = null;
    _extra.extraAttack = null;
    _extra.whiteAttack = null;
    _extra.infectTarget = null;
    _extra.scapegoat = null;
  }

  void _kill(Map<String, String> primary) {
    final victims = <String, String>{
      for (final e in primary.entries)
        if (alive.contains(e.key)) e.key: e.value,
    };
    for (var index = 0; index < victims.length; index++) {
      final lover = _extra.lovers[victims.keys.elementAt(index)];
      if (lover != null && alive.contains(lover))
        victims.putIfAbsent(lover, () => 'love');
    }
    if (victims.entries.any(
      (e) =>
          roles[e.key] == 'elder' &&
          _powerEnabled(e.key) &&
          ['vote', 'poison', 'hunter'].contains(e.value),
    )) {
      _extra.villagePowersLost = true;
      _log('effect', {'effect': 'elder_curse'});
    }
    for (final entry in victims.entries) {
      final id = entry.key;
      if (_isWolf(id)) _extra.packBroken = true;
      alive.remove(id);
      _recordDeath(id, entry.value);
      if (!deaths.contains(id)) deaths.add(id);
      if (roles[id] == 'hunter' && _powerEnabled(id)) {
        if (_hunter == null) {
          _hunter = id;
          _hunterDone = false;
        } else {
          _extra.hunters.add(id);
        }
      }
      if (roles[id] == 'scapegoat' &&
          entry.value == 'vote' &&
          _powerEnabled(id))
        _extra.scapegoat = id;
    }
  }

  void _beginReactions() {
    if (_extra.scapegoat != null) {
      _enter('scapegoat');
      return;
    }
    if (_hunter == null && _extra.hunters.isNotEmpty) {
      _hunter = _extra.hunters.removeAt(0);
      _hunterDone = false;
    }
    if (_hunter != null) {
      _enter('hunter');
      return;
    }
    _finish();
  }

  void _resolveExtraDeaths() {
    final victims = <String, String>{};
    void packAttack(String? id) {
      if (id == null || !alive.contains(id)) return;
      if (id == _extra.protected) {
        _log('effect', {'effect': 'protected', 'target': id});
        return;
      }
      if (roles[id] == 'elder' &&
          _powerEnabled(id) &&
          !_extra.elderHit.contains(id)) {
        _extra.elderHit.add(id);
        _log('effect', {'effect': 'elder_resists', 'target': id});
      } else {
        victims[id] = 'night';
      }
    }

    if (!_saved) {
      if (_attack != null &&
          _extra.infectTarget == _attack &&
          _attack != _extra.protected) {
        _extra.infections[_attack!] = night + 1;
        _log('effect', {'effect': 'infection_pending', 'target': _attack});
      } else {
        packAttack(_attack);
      }
    }
    if (_saved) _log('effect', {'effect': 'saved', 'target': _attack});
    if (_attack == null) _log('effect', {'effect': 'no_pack_victim'});
    packAttack(_extra.extraAttack);
    if (_extra.whiteAttack != null) victims[_extra.whiteAttack!] = 'white_wolf';
    if (_poison != null) victims[_poison!] = 'poison';
    _kill(victims);
    _extra.infections.removeWhere((id, _) => !alive.contains(id));
  }

  Map<String, dynamic>? _ability(String id) {
    final role = roles[id];
    Map<String, dynamic> choice(
      String command,
      String label,
      List<String> ids,
      int min,
      int max,
    ) => {
      'action': command,
      'label': label,
      'targets': ids,
      'min': min,
      'max': max,
      'can_pass': true,
    };
    if (phase == 'scapegoat' && id == _extra.scapegoat && !_done(id)) {
      return choice(
        'scapegoat.voters',
        'Choisir les électeurs du prochain jour',
        alive.toList(),
        0,
        alive.length,
      );
    }
    if (!alive.contains(id) || !_powerEnabled(id) || _done(id)) return null;
    final all = alive.toList();
    if (phase == 'metamorph' && role == 'metamorph' && !_extra.metamorphUsed)
      return choice('metamorph.swap', 'Échanger deux rôles', all, 2, 2);
    if (phase == 'cupid' && role == 'cupid' && !_extra.cupidUsed)
      return choice('cupid.link', 'Lier deux amoureux', all, 2, 2);
    if (phase == 'guardian' && role == 'guardian') {
      return choice(
        'guardian.protect',
        'Protéger un joueur',
        all
            .where(
              (target) =>
                  _extra.guardNight[id] != night - 1 ||
                  _extra.guardPrevious[id] != target,
            )
            .toList(),
        1,
        1,
      );
    }
    if (phase == 'alpha' &&
        role == 'alpha_wolf' &&
        !_extra.packBroken &&
        _attack != null) {
      return choice(
        'alpha.choose',
        'Désigner une seconde victime',
        all.where((target) => !_isWolf(target) && target != _attack).toList(),
        1,
        1,
      );
    }
    if (phase == 'white_wolf' && role == 'white_wolf' && night.isEven)
      return choice(
        'white_wolf.choose',
        'Éliminer un autre loup',
        all.where((target) => target != id && _isWolf(target)).toList(),
        1,
        1,
      );
    if (phase == 'infection' &&
        role == 'wolf_father' &&
        !_extra.infectionSpent.contains(id) &&
        _attack != null)
      return choice(
        'infection.convert',
        'Infecter la victime au lieu de la tuer',
        [_attack!],
        1,
        1,
      );
    if (phase == 'piper' && role == 'piper') {
      final targets = all
          .where((target) => target != id && !_extra.charmed.contains(target))
          .toList();
      final count = min(2, targets.length);
      if (count > 0)
        return choice(
          'piper.charm',
          'Charmer les joueurs choisis',
          targets,
          count,
          count,
        );
    }
    if (phase == 'wolves' && role == 'little_girl' && !_isWolf(id))
      return choice(
        'little_girl.peek',
        'Écouter un murmure (risque : 1 sur 3)',
        [],
        0,
        0,
      );
    return null;
  }

  Map<String, dynamic> _additionalPrivate(String id, bool canAct) {
    final ability = _ability(id);
    final reaction = phase == 'scapegoat' && id == _extra.scapegoat;
    final ready =
        !closed && !paused && remainingMilliseconds > 0 && (canAct || reaction);
    return {
      'camp': _camp(id),
      'camp_label': _camp(id) == 'wolves'
          ? 'Loups-Garous'
          : _camp(id) == 'village'
          ? 'Village'
          : 'Solitaire',
      'is_pack': _isWolf(id),
      'infected': _extra.infected.contains(id),
      'role_version': _extra.versions[id] ?? 0,
      'ability_submitted': _done(id),
      if (_extra.notices[id] != null) 'role_notice': _extra.notices[id],
      'vote_right': _eligibleVoters.contains(id),
      if (_extra.lovers[id] != null) ...{
        'lover': _extra.lovers[id],
        'mixed_lovers': _mixedLovers,
      },
      'charmed': _extra.charmed.contains(id),
      if (_extra.charmed.contains(id) || roles[id] == 'piper')
        'charmed_ids': _extra.charmed.where(alive.contains).toList(),
      if (_extra.peek[id] != null) 'peek_message': _extra.peek[id],
      if (_atNight &&
          _extra.protected != null &&
          (id == _extra.protected || roles[id] == 'guardian'))
        'guardian_protected_id': _extra.protected,
      if (_isWolf(id) && phase == 'wolves')
        'spotted_girls': _extra.spotted.toList(),
      if (ability != null) ...{'ability': ability, 'can_act': ready},
    };
  }

  Map<String, dynamic> get _additionalHost => {
    'protected': _extra.protected,
    'extra_attack': _extra.extraAttack,
    'white_attack': _extra.whiteAttack,
    'infection_target': _extra.infectTarget,
    'pending_infections': Map.of(_extra.infections),
    'infected': _extra.infected.toList(),
    'lovers': Map.of(_extra.lovers),
    'charmed': _extra.charmed.toList(),
    'pending_scapegoat': _extra.scapegoat,
    'ability_done': _extra.acted.toList(),
  };

  bool _actExtra(String id, Map<String, dynamic> action) {
    final ability = _ability(id);
    if (ability == null) return false;
    final command = action['action'];
    if (command == 'night.pass') {
      _markDone(id);
      return true;
    }
    if (command != ability['action']) return false;
    final raw = action['targets'];
    if (raw is! List || raw.any((v) => v is! String))
      throw ArgumentError('Sélection de joueurs invalide.');
    final chosen = raw.cast<String>();
    if (chosen.length < (ability['min'] as int) ||
        chosen.length > (ability['max'] as int) ||
        chosen.toSet().length != chosen.length ||
        chosen.any((id) => !(ability['targets'] as List).contains(id))) {
      throw ArgumentError(
        'Choisissez le nombre indiqué de joueurs distincts autorisés.',
      );
    }
    switch (command) {
      case 'metamorph.swap':
        final a = chosen[0], b = chosen[1], original = _roles[chosen[0]]!;
        _roles[a] = _roles[b]!;
        _roles[b] = original;
        _extra.metamorphUsed = true;
        for (final player in chosen) {
          _notice(
            player,
            'Votre carte a été échangée. Consultez votre nouveau rôle.',
          );
        }
      case 'cupid.link':
        _extra.lovers[chosen[0]] = chosen[1];
        _extra.lovers[chosen[1]] = chosen[0];
        _extra.cupidUsed = true;
      case 'guardian.protect':
        _extra.protected = chosen.single;
        _extra.guardPrevious[id] = chosen.single;
        _extra.guardNight[id] = night;
      case 'alpha.choose':
        _extra.extraAttack = chosen.single;
      case 'white_wolf.choose':
        _extra.whiteAttack = chosen.single;
      case 'infection.convert':
        _extra.infectTarget = chosen.single;
        _extra.infectionSpent.add(id);
      case 'piper.charm':
        _extra.charmed.addAll(chosen);
        if (_winningPipers.isNotEmpty) {
          _resolveVictory();
          _enter('ended');
        }
      case 'scapegoat.voters':
        _extra.voters = chosen.toSet();
        _extra.restrictedNight = night + 1;
      case 'little_girl.peek':
        _extra.peek[id] = _wolfMessages.isEmpty
            ? 'Aucun murmure capté.'
            : _wolfMessages[_chanceDraw(_wolfMessages.length)]['text']!;
        if (_chanceDraw(3) == 0) _extra.spotted.add(id);
      default:
        return false;
    }
    _markDone(id);
    return true;
  }
}
