part of 'night_game.dart';

extension _VotingVariants on NightGame {
  List<Map<String, dynamic>> _votingAbilities(String id) {
    if (!_powerEnabled(id) &&
        _mayor != id &&
        !_expanded.campDemands.containsKey(id))
      return [];
    if (phase == 'mediation' && _expanded.pendingMediator == id) {
      return [
        _expandedChoice(
          'scapegoat.revote',
          'Relancer le scrutin · je ne voterai pas dans ce second tour',
          [],
          0,
        ),
        _expandedChoice(
          'scapegoat.accept',
          'Accepter mon sacrifice pour cette égalité',
          [],
          0,
        ),
      ];
    }
    if (phase == 'scapegoat' &&
        _extra.scapegoat == id &&
        editionOf(id) == 'horror' &&
        !_spent(id, 'camp_mark')) {
      return [
        _expandedChoice(
          'scapegoat.mark',
          'Marquer un survivant : révéler son camp ou perdre son prochain vote',
          alive.toList(),
          1,
        ),
      ];
    }
    if (!alive.contains(id)) return [];
    if ((_expanded.campDemands[id] ?? -1) >= night) {
      return [
        _expandedChoice(
          'mark.reveal',
          'Révéler publiquement mon camp et conserver mon vote',
          [],
          0,
        ),
        _expandedChoice(
          'mark.refuse',
          'Garder mon camp secret et perdre mon prochain vote',
          [],
          0,
        ),
      ];
    }
    if (_mayor == id) {
      if (phase == 'voting' &&
          mayorEdition == 'intense' &&
          !_expanded.mayorStrategyUsed &&
          !_expanded.revote) {
        return [
          _expandedChoice(
            'mayor.strategy',
            'Renoncer au vote double pour imposer un second scrutin en cas d’égalité · une fois',
            [],
            0,
          ),
        ];
      }
      if (['day', 'voting', 'vote_result'].contains(phase) &&
          mayorEdition == 'horror') {
        return [
          _expandedChoice(
            'mayor.testament',
            'Sceller ou modifier secrètement mon successeur',
            alive.where((p) => p != id).toList(),
            1,
          ),
        ];
      }
    }
    return [];
  }

  bool _actVotingVariant(String id, Map<String, dynamic> action) {
    final ability = _votingAbilities(
      id,
    ).where((a) => a['action'] == action['action']).firstOrNull;
    if (ability == null) return false;
    final chosen = _variantTargets(
      action,
      (ability['targets'] as List).cast<String>(),
      ability['min'] as int,
    );
    switch (action['action']) {
      case 'scapegoat.revote':
        _spend(id, 'mediation');
        _expanded.pendingMediator = null;
        _startSecondBallot(excluded: id);
      case 'scapegoat.accept':
        _acceptMediation();
      case 'scapegoat.mark':
        _spend(id, 'camp_mark');
        _expanded.campDemands[chosen.single] = night + 1;
        _expanded.markBans[chosen.single] = night + 1;
        _notice(
          chosen.single,
          'Le Bouc maudit vous marque. Révélez publiquement votre camp ou perdez votre prochain scrutin de condamnation. Sans réponse, votre camp reste secret et le vote est perdu.',
        );
      case 'mark.reveal':
        _expanded.revealedCamps[id] = _campGroup(id);
        _expanded.markBans.remove(id);
        _expanded.campDemands.remove(id);
      case 'mark.refuse':
        _expanded.campDemands.remove(id);
      case 'mayor.strategy':
        _expanded.mayorStrategyUsed = true;
        _expanded.strategyNight = night;
      case 'mayor.testament':
        _expanded.testament = chosen.single;
        _notice(
          id,
          'Votre testament est scellé. Il ne sera dévoilé qu’à votre mort.',
        );
    }
    return true;
  }

  int _ballotWeight(String id) =>
      id == _mayor && _expanded.strategyNight != night ? 2 : 1;

  bool _interceptTie(
    String? goat,
    Map<String, int> counts,
    int blank,
    int eligible,
  ) {
    if (_expanded.revote || _expanded.acceptMediation) return false;
    final strategy = _expanded.strategyNight == night;
    final mediator =
        goat != null &&
        editionOf(goat) == 'intense' &&
        !_spent(goat, 'mediation');
    if (!strategy && !mediator) return false;
    _voteSummary = {
      'counts': Map.of(counts),
      'blank': blank,
      'eligible': eligible,
      'cast': _votes.length,
      'abstentions': eligible - _votes.length,
      'eliminated': null,
      'reason': strategy ? 'mayor_revote' : 'mediation_pending',
    };
    _log('vote_round', {..._voteSummary!, 'ballots': Map.of(_votes)});
    if (strategy) {
      _startSecondBallot();
    } else {
      _expanded.pendingMediator = goat;
      _enter('mediation');
    }
    return true;
  }

  void _acceptMediation() {
    _expanded.pendingMediator = null;
    _expanded.acceptMediation = true;
    _resolveVote();
  }

  void _startSecondBallot({String? excluded}) {
    _expanded.revote = true;
    _expanded.revoteExcluded = excluded;
    _votes.clear();
    _voteSummary = null;
    _enter('voting');
    deadline = _clock().add(Duration(seconds: _expanded.voteSeconds));
  }

  void _finishVoteVariants() {
    _expanded.revote = false;
    _expanded.revoteExcluded = null;
    _expanded.pendingMediator = null;
    _expanded.acceptMediation = false;
    _expanded.strategyNight = -1;
  }

  void _applyTestament() {
    if (_pendingMayor == null ||
        mayorEdition != 'horror' ||
        _expanded.testament == null)
      return;
    final target = _expanded.testament!;
    final from = _pendingMayor;
    _expanded.testament = null;
    _pendingMayor = null;
    final valid = alive.contains(target);
    _expanded.publicTestament = {
      'actor': from,
      'target': target,
      'valid': valid,
    };
    if (valid) {
      _mayor = target;
    } else {
      _mayorElectionNight = -1;
    }
    _log('mayor_succession', {..._expanded.publicTestament!, 'sealed': true});
  }
}
