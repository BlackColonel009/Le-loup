part of 'night_game.dart';

class _ExpandedVariantState {
  final nightTargets = <String, int>{};
  final watches = <String, String>{};
  final markedHouses = <String>{};
  final hunterWards = <String>{};
  final hunterShots = <String, int>{};
  final whiteDeferred = <String, int>{};
  final deniedVotes = <String, int>{};
  final infectionDue = <String, int>{};
  final dormantOwners = <String, String>{};
  final idiotBallots = <String, int>{};
  final fakeCharmed = <String>{};
  final publicContagion = <String, int>{};
  final elderGifts = <String>{};
  final presages = <String, String>{};
  final campDemands = <String, int>{}, markBans = <String, int>{};
  final revealedCamps = <String, String>{};
  bool revote = false, acceptMediation = false, mayorStrategyUsed = false;
  String? pendingMediator, revoteExcluded, testament;
  Map<String, dynamic>? publicTestament;
  int strategyNight = -1, voteSeconds = 120;
  String? loversEdition, loversSource;
  int loversMeetingNight = -1;
  bool loversMeetingDone = false,
      loversDeclined = false,
      sistersDeclined = false;
  final loversAgreed = <String>{}, sistersChatAgreed = <String>{};
  final sistersTransferVotes = <String, String>{};
  final bondChats = <String, _BondChannel>{};
  ({String from, String to})? sisterRedirect;
  int voteRounds = 0;
  final poisons = <({String target, String actor, int due, bool curse})>[];
}

extension _ExpandedVariants on NightGame {
  Map<String, dynamic> _expandedChoice(
    String command,
    String label,
    List<String> targets,
    int minimum, {
    int? maximum,
  }) => {
    'action': command,
    'label': label,
    'targets': targets,
    'min': minimum,
    'max': maximum ?? minimum,
    'can_pass': false,
  };

  List<Map<String, dynamic>> _expandedAbilities(String id) {
    return [
      ..._votingAbilities(id),
      if (_powerEnabled(id)) ...[
        ..._predatorAbilities(id),
        ..._solitaryAbilities(id),
        ..._villageAbilities(id),
        ..._bondAbilities(id),
        ..._coreExpandedAbilities(id),
      ],
    ];
  }

  List<Map<String, dynamic>> _coreExpandedAbilities(String id) {
    final living = alive.toList();
    if (phase == 'hunter' &&
        _hunter == id &&
        !_hunterDone &&
        _variant(id, 'hunter', 'intense')) {
      return [
        _expandedChoice(
          'hunter.ward',
          'Renoncer au tir et transmettre un bouclier contre une attaque de la meute',
          living.where((p) => !_cannotProtect(p)).toList(),
          1,
        ),
      ];
    }
    if (!alive.contains(id)) return [];
    if (phase == 'village_watch' &&
        roles[id] == 'villager' &&
        editionOf(id) != 'classic' &&
        !_spent(id, 'watch')) {
      return [
        _expandedChoice(
          'villager.watch',
          editionOf(id) == 'horror'
              ? 'Veiller une maison · une fois · marque publique au matin'
              : 'Observer si une maison a reçu un pouvoir · une fois',
          living.where((p) => p != id).toList(),
          1,
        ),
      ];
    }
    if (phase == 'witch' &&
        roles[id] == 'witch' &&
        !_witchDone.contains(id) &&
        !_deathSpent.contains(id)) {
      if (editionOf(id) == 'intense')
        return [
          _expandedChoice(
            'witch.delay',
            'Poison différé au réveil suivant · consomme la potion de mort',
            living,
            1,
          ),
        ];
      if (editionOf(id) == 'horror')
        return [
          _expandedChoice(
            'witch.curse',
            'Maudire : mort au prochain crépuscule sauf exécution d’un loup · consomme le poison',
            living,
            1,
          ),
        ];
    }
    return [];
  }

  bool _actExpanded(String id, Map<String, dynamic> action) {
    if (_actVotingVariant(id, action)) return true;
    if (_actPredatorVariant(id, action)) return true;
    if (_actSolitaryVariant(id, action)) return true;
    if (_actVillageVariant(id, action)) return true;
    if (_actBondVariant(id, action)) return true;
    final ability = _expandedAbilities(
      id,
    ).where((a) => a['action'] == action['action']).firstOrNull;
    if (ability == null) return false;
    final chosen = _variantTargets(
      action,
      (ability['targets'] as List).cast<String>(),
      ability['min'] as int,
    );
    switch (action['action']) {
      case 'villager.watch':
        _spend(id, 'watch');
        _expanded.watches[id] = chosen.single;
      case 'witch.delay':
      case 'witch.curse':
        _deathSpent.add(id);
        final curse = action['action'] == 'witch.curse';
        _expanded.poisons.add((
          target: chosen.single,
          actor: id,
          due: night + 1,
          curse: curse,
        ));
        if (curse)
          _notice(
            chosen.single,
            'Vous êtes maudit : vous mourrez au prochain crépuscule, sauf si le village exécute un membre de la meute aujourd’hui.',
          );
        _notice(
          id,
          'Votre potion de mort est consommée. Vous pouvez encore confirmer votre potion de vie pendant cet appel si elle est disponible.',
        );
      case 'hunter.ward':
        _expanded.hunterWards.add(chosen.single);
        _hunterDone = true;
        _notice(
          chosen.single,
          'Le Franc-tireur vous transmet un bouclier : il arrêtera une attaque de la meute, puis disparaîtra.',
        );
    }
    return true;
  }

  void _resetExpandedNight() {
    _expanded.nightTargets.clear();
    _expanded.watches.clear();
    _expanded.markedHouses.clear();
    _expanded.presages.clear();
    _expanded.loversAgreed.clear();
    _expanded.sistersChatAgreed.clear();
    _expanded.sistersTransferVotes.clear();
    _expanded.loversDeclined = false;
    _expanded.sistersDeclined = false;
    _expanded.sisterRedirect = null;
    _expanded.bondChats.clear();
    _expanded.infectionDue.clear();
    _expanded.whiteDeferred.removeWhere((_, due) => due < night);
  }

  void _countNightTarget(String? id) {
    if (id != null)
      _expanded.nightTargets[id] = (_expanded.nightTargets[id] ?? 0) + 1;
  }

  void _countAcceptedNightAction(String id, Map<String, dynamic> action) {
    if (!_atNight) return;
    final command = action['action'] as String;
    if (command == 'witch.potions') {
      if (action['save'] == true) _countNightTarget(_attack);
      _countNightTarget(action['kill'] as String?);
      return;
    }
    // A collective hunt counts once, after the final consensus. Observers do
    // not count their own observation, which would make every clue positive.
    if (command == 'wolves.choose' ||
        command == 'villager.watch' ||
        command == 'sisters.transfer_agree' ||
        command.endsWith('.chat') ||
        command == 'reaction.send' ||
        command == 'night.pass')
      return;
    if (action['target'] is String)
      _countNightTarget(action['target'] as String);
    for (final target in action['targets'] as List? ?? []) {
      if (target is String) _countNightTarget(target);
    }
  }

  void _resolveWatches() {
    for (final entry in _expanded.watches.entries) {
      final count = min(2, _expanded.nightTargets[entry.value] ?? 0);
      _variantInfo[entry.key] = {
        'kind': 'watch',
        'target': entry.value,
        'count': count,
        'watched': count > 0,
        'detailed': editionOf(entry.key) == 'horror',
      };
      if (editionOf(entry.key) == 'horror')
        _expanded.markedHouses.add(entry.key);
      _log('effect', {
        'effect': 'watch_result',
        'actor': entry.key,
        'target': entry.value,
        'count': count,
      });
    }
  }

  bool _consumeHunterWard(String? id) {
    if (id == null || !_expanded.hunterWards.remove(id)) return false;
    _log('effect', {'effect': 'hunter_ward', 'target': id});
    return true;
  }

  void _resolveDelayedPoisons(Map<String, String> victims) {
    final due = _expanded.poisons
        .where((p) => !p.curse && p.due <= night)
        .toList();
    for (final poison in due) {
      if (alive.contains(poison.target)) victims[poison.target] = 'poison';
      _expanded.poisons.remove(poison);
    }
  }

  void _cancelCursesAfterVote(String? eliminated) {
    if (eliminated == null || !_isWolf(eliminated)) return;
    final canceled = _expanded.poisons
        .where((p) => p.curse && p.due == night + 1)
        .toList();
    for (final poison in canceled) {
      _expanded.poisons.remove(poison);
      _notice(
        poison.target,
        'Le village a exécuté un loup. Votre malédiction est levée.',
      );
      _log('effect', {
        'effect': 'curse_lifted',
        'target': poison.target,
        'actor': poison.actor,
      });
    }
  }

  bool _resolveTwilightPoisons() {
    final due = _expanded.poisons
        .where((p) => p.curse && p.due <= night)
        .toList();
    final victims = <String, String>{};
    for (final poison in due) {
      if (alive.contains(poison.target)) victims[poison.target] = 'poison';
      _expanded.poisons.remove(poison);
    }
    if (victims.isEmpty) return false;
    _enter('sleep');
    _kill(victims);
    _afterReactions = 'sleep';
    _beginReactions();
    return true;
  }

  Map<String, dynamic> get _expandedPublic => {
    if (_expanded.strategyNight == night) 'mayor_strategy_active': true,
    if (_expanded.revealedCamps.isNotEmpty)
      'revealed_camps': Map.of(_expanded.revealedCamps),
    if (_expanded.publicTestament != null)
      'mayor_testament': Map.of(_expanded.publicTestament!),
    if (_expanded.revote) 'second_ballot': true,
    if (_expanded.presages.isNotEmpty)
      'presages': [
        for (final e in _expanded.presages.entries)
          {'actor': e.key, 'target': e.value},
      ],
    if (_expanded.publicContagion.isNotEmpty)
      'contagion_targets': [
        for (final e in _expanded.publicContagion.entries)
          if (e.value >= night) e.key,
      ],
    if (!_atNight && _expanded.markedHouses.isNotEmpty)
      'marked_houses': _expanded.markedHouses.toList(),
  };
  Map<String, dynamic> get _expandedHost => {
    'sealed_testament': _expanded.testament,
    'delayed_poisons': [
      for (final p in _expanded.poisons)
        {
          'actor': p.actor,
          'target': p.target,
          'due_night': p.due,
          'curse': p.curse,
        },
    ],
  };
}
