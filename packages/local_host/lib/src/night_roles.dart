part of 'night_game.dart';

const _nightCalls = {
  'metamorph': ('metamorph', 'le Métamorphe'),
  'cupid': ('cupid', 'Cupidon'),
  'sisters': ('sisters', 'les Deux Sœurs'),
  'guardian': ('guardian', 'le Salvateur'),
  'seer': ('seer', 'la Voyante'),
  'wolves': ('pack', 'les Loups-Garous'),
  'alpha': ('alpha_wolf', 'le Grand Méchant Loup'),
  'infection': ('wolf_father', 'le Père des Loups'),
  'witch': ('witch', 'la Sorcière'),
  'white_wolf': ('white_wolf', 'le Loup Blanc'),
  'piper': ('piper', 'le Joueur de Flûte'),
  'sulfuron': ('sulfuron', 'Sulfuron'),
  'village_watch': ('villager', 'les Éclaireurs et Veilleurs'),
  'elder_watch': ('elder', 'les Anciens du village'),
  'lovers': ('bond', 'les Amoureux'),
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
    return ['piper', 'angel', 'sulfuron'].contains(_roles[id])
        ? _roles[id]!
        : 'village';
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
            (!_extra.gracedIdiots.contains(id) ||
                _expanded.idiotBallots[id] == night) &&
            (phase == 'mayor_election' || _expanded.deniedVotes[id] != night) &&
            _expanded.revoteExcluded != id &&
            (phase == 'mayor_election' || _expanded.markBans[id] != night) &&
            (_extra.restrictedNight != night || _extra.voters!.contains(id)),
      )
      .toSet();

  bool _callExists(String action) {
    if (action == 'lovers') return _loversCallExists;
    final role = _nightCalls[action]!.$1;
    if (role == 'pack') return alive.any(_isWolf);
    if (!_hasLivingRole(role)) return false;
    return switch (action) {
      'elder_watch' => alive.any(
        (id) =>
            roles[id] == 'elder' &&
            (editionOf(id) == 'intense' && !_extra.elderHit.contains(id) ||
                editionOf(id) == 'horror' && !_spent(id, 'presage')),
      ),
      'village_watch' => alive.any(
        (id) =>
            roles[id] == 'villager' &&
            editionOf(id) != 'classic' &&
            !_spent(id, 'watch'),
      ),
      'metamorph' =>
        !_extra.metamorphUsed &&
            alive.any(
              (id) =>
                  roles[id] == 'metamorph' &&
                  (night == 1 || editionOf(id) == 'horror'),
            ),
      'cupid' => night == 1 && !_extra.cupidUsed,
      'sisters' =>
        night == 1 && _recognizedSisters.isEmpty || _sisterVariantCallExists,
      'alpha' => alive.any(_alphaCanAttack),
      'infection' => alive.any(
        (id) =>
            roles[id] == 'wolf_father' &&
            (!_extra.infectionSpent.contains(id) ||
                _dormantTargets(id).isNotEmpty),
      ),
      'white_wolf' => alive.any(_whiteCanAttack),
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
        _loversCallExists &&
        !_nightCompleted.contains('lovers')) {
      return 'Appelez ou passez les Amoureux avant la chasse.';
    }
    if (action == 'wolves' &&
        _sisterVariantCallExists &&
        !_nightCompleted.contains('sisters')) {
      return 'Appelez ou passez les Sœurs avant la chasse.';
    }
    if (action == 'wolves' &&
        _callExists('elder_watch') &&
        !_nightCompleted.contains('elder_watch')) {
      return 'Appelez ou passez l’Ancien avant la chasse.';
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
            _dependency(preceding) == null &&
            !_nightCompleted.contains(preceding)) {
          return 'Terminez ou passez ${_nightCalls[preceding]!.$2} avant la Sorcière.';
        }
      }
    }
    if (['alpha', 'infection'].contains(action) &&
        _attack == null &&
        !(action == 'infection' &&
            alive.any((id) => _dormantTargets(id).isNotEmpty)))
      return 'Aucune victime de la meute cette nuit.';
    if (action == 'alpha' &&
        alive.every((id) => _isWolf(id) || id == _attack)) {
      return 'Aucune seconde cible vivante hors de la meute.';
    }
    return null;
  }

  List<Map<String, dynamic>> _buildNightActions() {
    final actions = <Map<String, dynamic>>[];
    for (final entry in _nightCalls.entries) {
      final action = entry.key;
      final exists = _callExists(action);
      final completed = _nightCompleted.contains(action);
      String? reason;
      if (!exists && !completed) {
        if (action == 'alpha' && _hasLivingRole('alpha_wolf')) {
          final alpha = alive.firstWhere((id) => roles[id] == 'alpha_wolf');
          reason = editionOf(alpha) == 'intense'
              ? 'L’ultime seconde attaque a déjà été utilisée.'
              : 'La seconde attaque est perdue depuis la mort d’un loup.';
        } else if (action == 'infection' && _hasLivingRole('wolf_father')) {
          reason = 'L’infection unique a déjà été utilisée.';
        } else {
          continue;
        }
      } else if (!completed) {
        reason = _dependency(action);
      }
      actions.add({
        'action': action,
        'label': 'Appeler ${entry.value.$2}',
        'completed': completed,
        'available': phase == 'sleep' && exists && !completed && reason == null,
        if (reason != null) 'reason': reason,
      });
    }
    return actions;
  }

  String _extraAnnouncement() => phase == 'mayor_election'
      ? 'Le village élit son Maire. Chaque bulletin compte pour une voix.'
      : phase == 'mayor_succession'
      ? 'Le Maire transmet son titre à un joueur vivant.'
      : phase == 'sisters'
      ? 'Deux Sœurs, ouvrez les yeux et reconnaissez-vous.'
      : phase == 'scapegoat'
      ? 'Bouc émissaire, désigne les joueurs qui pourront voter demain.'
      : phase == 'lovers'
      ? 'Amoureux, ouvrez les yeux. Votre rencontre commence.'
      : phase == 'elder_watch'
      ? 'Ancien, ouvre les yeux. Souhaites-tu transmettre ta résistance ou annoncer ton présage ?'
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
    'angel' => 'L’Ange a atteint son objectif au vote et remporte la partie.',
    'lovers' => 'Les amoureux de camps opposés remportent ensemble la partie.',
    'sulfuron' =>
      'Sulfuron a piégé le village. Le Fourbe remporte seul la partie !',
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
    } else if (alive.any(
      (id) =>
          _camp(id) == 'sulfuron' &&
          alive.every((p) => p == id || _camp(p) == 'village'),
    )) {
      winner = 'sulfuron';
      _extra.winners.add(alive.firstWhere((id) => _camp(id) == 'sulfuron'));
    } else {
      final friendly = alive.where((id) => _camp(id) == 'wolves').length;
      final white = alive.any((id) => _camp(id) == 'white_wolf');
      final piper = alive.any((id) => _camp(id) == 'piper');
      if (!alive.any(_isWolf) &&
          !piper &&
          !alive.any((id) => _camp(id) == 'sulfuron')) {
        winner = 'village';
        _extra.winners.addAll(roles.keys.where((id) => _camp(id) == 'village'));
      } else if (!white && friendly > 0 && friendly * 2 >= alive.length) {
        winner = 'wolves';
        _extra.winners.addAll(roles.keys.where((id) => _camp(id) == 'wolves'));
      }
    }
  }

  void _startExtraNight() {
    _resetVariantsNight();
    _resetExpandedNight();
    _applyDueInfections();
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
    victims.removeWhere((id, cause) => _sulfuronPreventsDeath(id, cause));
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
      if (_mayor == id) {
        _pendingMayor = id;
        _mayor = null;
      }
      if (_isWolf(id)) _extra.packBroken = true;
      alive.remove(id);
      _recordDeath(id, entry.value, victims.keys);
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
    _applyTestament();
    if (_pendingMayor != null) {
      _resolveVictory();
      if (winner == null && alive.isNotEmpty) {
        _enter('mayor_succession');
        return;
      }
      _pendingMayor = null;
    }
    _finish();
  }

  void _resolveExtraDeaths() {
    final savedTarget = _attack;
    final wouldDie =
        savedTarget != null &&
        !(roles[savedTarget] == 'elder' &&
            _powerEnabled(savedTarget) &&
            !_extra.elderHit.contains(savedTarget)) &&
        !(_powerEnabled(savedTarget) &&
            _expanded.elderGifts.contains(savedTarget)) &&
        !_expanded.presages.entries.any(
          (e) =>
              e.value == savedTarget &&
              alive.contains(e.key) &&
              _powerEnabled(e.key),
        );
    final victims = <String, String>{};
    void packAttack(String? id) {
      if (id == null || !alive.contains(id)) return;
      id = _redirectSisterAttack(id)!;
      if (_consumeHunterWard(id)) return;
      if (_guardBlocksPack(id)) {
        _log('effect', {
          'effect': 'protected',
          'target': id,
          'actor': _guardActor,
        });
        return;
      }
      if (_blockByElderVariant(id)) return;
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
          !_guardBlocksPack(_attack)) {
        _extra.infections[_attack!] =
            _expanded.infectionDue[_attack] ?? night + 1;
        _log('effect', {'effect': 'infection_pending', 'target': _attack});
      } else {
        packAttack(_attack);
      }
    }
    if (_attack == null) _log('effect', {'effect': 'no_pack_victim'});
    packAttack(_extra.extraAttack);
    if (_extra.whiteAttack != null) victims[_extra.whiteAttack!] = 'white_wolf';
    if (_poison != null) victims[_poison!] = 'poison';
    _resolveDelayedPoisons(victims);
    _resolveVariantProtection(victims);
    _kill(victims);
    if (_saved) {
      _log('effect', {
        'effect': 'saved',
        'target': _attack,
        'actor': _rescuer,
        'effective':
            wouldDie &&
            _attack != null &&
            alive.contains(_attack) &&
            _extra.infectTarget != _attack,
      });
    }
    _resolveWatches();
    _applyDueInfections();
    if (_saved &&
        _extra.infectTarget != _attack &&
        _attack != null &&
        alive.contains(_attack) &&
        _rescuer != null) {
      _rescues.add({
        'id': 'rescue-$night',
        'player': _attack,
        'rescuer': _rescuer,
        'night': night,
      });
    }
    _extra.infections.removeWhere((id, _) => !alive.contains(id));
  }

  Map<String, dynamic>? _ability(String id) {
    if (phase == 'mayor_succession' && _pendingMayor == id)
      return {
        'action': 'mayor.succeed',
        'label': 'Transmettre mon titre de Maire',
        'targets': alive.toList(),
        'min': 1,
        'max': 1,
        'can_pass': false,
      };
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
    if (phase == 'sulfuron' && role == 'sulfuron') {
      return choice(
        'sulfuron.reveal',
        'Révélation-piège · gagnez une vie si les loups ou le prochain vote éliminent la cible révélée',
        [],
        0,
        0,
      );
    }
    if (phase == 'metamorph' && role == 'metamorph') {
      if (_metaPeek.containsKey(id))
        return choice(
          'metamorph.swap',
          'Échanger les deux cartes consultées',
          _metaPeek[id]!,
          2,
          2,
        );
      if (!_extra.metamorphUsed && (night == 1 || editionOf(id) == 'horror'))
        return choice(
          editionOf(id) == 'intense' ? 'metamorph.peek' : 'metamorph.swap',
          editionOf(id) == 'intense'
              ? 'Consulter deux camps avant l’échange'
              : 'Échanger deux rôles',
          all,
          2,
          2,
        );
    }
    if (phase == 'cupid' && role == 'cupid' && !_extra.cupidUsed)
      return choice('cupid.link', 'Lier deux amoureux', all, 2, 2);
    if (phase == 'guardian' && role == 'guardian') {
      return choice(
        'guardian.protect',
        'Protéger un joueur',
        all
            .where(
              (target) =>
                  !_cannotProtect(target) &&
                  (_extra.guardNight[id] != night - 1 ||
                      _extra.guardPrevious[id] != target),
            )
            .toList(),
        1,
        1,
      );
    }
    if (phase == 'alpha' &&
        role == 'alpha_wolf' &&
        _alphaCanAttack(id) &&
        _attack != null) {
      return choice(
        'alpha.choose',
        'Désigner une seconde victime',
        all.where((target) => !_isWolf(target) && target != _attack).toList(),
        1,
        1,
      );
    }
    if (phase == 'white_wolf' && _whiteCanAttack(id))
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
    final reaction =
        phase == 'scapegoat' && id == _extra.scapegoat ||
        phase == 'mayor_succession' && id == _pendingMayor;
    final ready =
        !closed && !paused && remainingMilliseconds > 0 && (canAct || reaction);
    return {
      'camp': _camp(id),
      'edition': editionOf(id),
      if (cardVariant(roles[id] ?? '', editionOf(id)) != null)
        'variant': cardVariant(roles[id]!, editionOf(id)),
      'variant_abilities': _variantAbilities(id),
      if (_variantInfo[id] != null) 'variant_result': _variantInfo[id],
      'veil_requested': _veilRequests.contains(id),
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
      if (phase == 'wolves' && alive.contains(id) && _isWolf(id))
        'spotted_girls': _extra.spotted.toList(),
      if (phase == 'wolves' &&
          roles[id] == 'little_girl' &&
          _extra.spotted.contains(id))
        'peek_spotted': true,
      if (ability != null) ...{'ability': ability, 'can_act': ready},
      if (_expandedAbilities(id).isNotEmpty) ...{
        'can_act':
            !closed &&
            !paused &&
            (!timed || remainingMilliseconds > 0) &&
            (canAct ||
                reaction ||
                !timed && alive.contains(id) ||
                phase == 'hunter' && _hunter == id),
      },
      ..._solitaryPrivate(id),
      if (_bondPrivate(id) != null) 'bond_chat': _bondPrivate(id),
    };
  }

  Map<String, dynamic> get _additionalHost => {
    if (phase == 'wolves') 'spotted_girls': _extra.spotted.toList(),
    'editions': Map.of(_editions),
    'variant_results': {
      for (final entry in _variantInfo.entries) entry.key: entry.value,
    },
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
        _swapCardMemory(a, b);
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
        _expanded.loversEdition = editionOf(id);
        _expanded.loversSource = _cardTokens[id];
        _expanded.loversMeetingNight = night;
      case 'guardian.protect':
        _guardActor = id;
        _extra.protected = chosen.single;
        _extra.guardPrevious[id] = chosen.single;
        _extra.guardNight[id] = night;
      case 'alpha.choose':
        if (_extra.packBroken) _spend(id, 'last_hunt');
        _extra.extraAttack = chosen.single;
      case 'white_wolf.choose':
        _expanded.whiteDeferred.remove(id);
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
        final available = List<Map<String, String>>.from(_wolfMessages);
        final snippets = <String>[];
        final count = editionOf(id) == 'intense' ? 2 : 1;
        for (var i = 0; i < count && available.isNotEmpty; i++) {
          snippets.add(
            available.removeAt(_chanceDraw(available.length))['text']!,
          );
        }
        _extra.peek[id] = snippets.isEmpty
            ? 'Aucun murmure capté.'
            : snippets.join('\n');
        if (_chanceDraw(3) == 0) _extra.spotted.add(id);
      default:
        return false;
    }
    _markDone(id);
    return true;
  }
}
