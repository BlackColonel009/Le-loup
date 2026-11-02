part of 'night_game.dart';

extension _SolitaryVariants on NightGame {
  bool _cannotProtect(String? id) =>
      id != null && _variant(id, 'angel', 'horror') && _expanded.voteRounds < 2;

  List<Map<String, dynamic>> _solitaryAbilities(String id) {
    if (!alive.contains(id) || !_powerEnabled(id)) return [];
    if (roles[id] == 'idiot' && _extra.gracedIdiots.contains(id)) {
      if (phase == 'voting' &&
          editionOf(id) == 'intense' &&
          !_spent(id, 'lucid_ballot')) {
        return [
          _expandedChoice(
            'idiot.ballot',
            'Utiliser mon unique bulletin exceptionnel pendant ce scrutin',
            [],
            0,
          ),
        ];
      }
      if (phase == 'vote_result' &&
          _voteSummary?['graced'] == id &&
          editionOf(id) == 'horror' &&
          !_spent(id, 'contagion')) {
        return [
          _expandedChoice(
            'idiot.contagion',
            'Désigner publiquement un autre joueur privé du vote de demain',
            alive.where((p) => p != id).toList(),
            1,
          ),
        ];
      }
    }
    if (phase == 'piper' && roles[id] == 'piper' && !_done(id)) {
      final targets = alive
          .where((p) => p != id && !_extra.charmed.contains(p))
          .toList();
      if (editionOf(id) == 'intense' &&
          !_spent(id, 'triple_charm') &&
          targets.length >= 3) {
        return [
          _expandedChoice(
            'piper.triple',
            'Charmer trois joueurs · une fois',
            targets,
            3,
          ),
        ];
      }
      if (editionOf(id) == 'horror' &&
          !_spent(id, 'false_charm') &&
          targets.isNotEmpty) {
        return [
          _expandedChoice(
            'piper.illusion',
            'Ajouter un faux charmé à leur liste · ne compte pas pour ma victoire',
            targets,
            1,
          ),
        ];
      }
    }
    return [];
  }

  bool _actSolitaryVariant(String id, Map<String, dynamic> action) {
    final ability = _solitaryAbilities(
      id,
    ).where((a) => a['action'] == action['action']).firstOrNull;
    if (ability == null) return false;
    final chosen = _variantTargets(
      action,
      (ability['targets'] as List).cast<String>(),
      ability['min'] as int,
    );
    switch (action['action']) {
      case 'idiot.ballot':
        _spend(id, 'lucid_ballot');
        _expanded.idiotBallots[id] = night;
      case 'idiot.contagion':
        _spend(id, 'contagion');
        _expanded.deniedVotes[chosen.single] = night + 1;
        _expanded.publicContagion[chosen.single] = night + 1;
        _notice(
          chosen.single,
          'Le Fou contagieux vous désigne publiquement : vous perdez le scrutin de condamnation de demain, mais gardez votre parole.',
        );
      case 'piper.triple':
        _spend(id, 'triple_charm');
        _extra.charmed.addAll(chosen);
        _markDone(id);
        if (_winningPipers.isNotEmpty) {
          _resolveVictory();
          _enter('ended');
        }
      case 'piper.illusion':
        _spend(id, 'false_charm');
        _expanded.fakeCharmed.add(chosen.single);
    }
    return true;
  }

  void _resolveAngelVote(String? eliminated) {
    _expanded.voteRounds++;
    _extra.firstVoteResolved = true;
    for (final id in alive.where((p) => roles[p] == 'angel').toList()) {
      final limit = editionOf(id) == 'horror' ? 2 : 1;
      if (id == eliminated && !_isWolf(id) && _expanded.voteRounds <= limit) {
        _extra.angelWinner = id;
      } else if (id != eliminated && _expanded.voteRounds >= limit) {
        final vigilant = editionOf(id) == 'intense';
        _roles[id] = 'villager';
        if (!vigilant) _editions[id] = 'classic';
        _notice(
          id,
          vigilant
              ? 'Votre objectif initial est terminé : vous devenez l’Éclaireur Intense, avec une observation unique.'
              : 'Votre objectif initial est terminé : vous devenez Simple Villageois, sans pouvoir nocturne.',
        );
        _log('effect', {
          'effect': 'angel_becomes_villager',
          'target': id,
          'edition': editionOf(id),
        });
      }
    }
  }

  Map<String, dynamic> _solitaryPrivate(String id) => {
    if (roles[id] == 'witch') 'save_blocked': _cannotProtect(_attack),
    if (phase != 'ended' && _extra.charmed.contains(id) && roles[id] != 'piper')
      'charmed_ids': {
        ..._extra.charmed,
        ..._expanded.fakeCharmed,
      }.where(alive.contains).toList(),
  };
}
