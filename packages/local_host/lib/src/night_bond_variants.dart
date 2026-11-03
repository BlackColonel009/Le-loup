part of 'night_game.dart';

class _BondChannel {
  _BondChannel(this.kind, this.members, this.startRemaining)
    : duration = min(60000, startRemaining);
  final String kind;
  final Set<String> members;
  final int startRemaining, duration;
  final messages = <Map<String, String>>[];
}

extension _BondVariants on NightGame {
  List<String> get _livingSisters =>
      alive.where((id) => roles[id] == 'sisters').toList();
  String? _sisterSource(String edition, String power) => _livingSisters
      .where(
        (id) =>
            editionOf(id) == edition && _powerEnabled(id) && !_spent(id, power),
      )
      .firstOrNull;
  bool get _sisterVariantCallExists =>
      _livingSisters.length == 2 &&
      (_sisterSource('intense', 'sister_chat') != null ||
          _sisterSource('horror', 'sister_transfer') != null);
  bool get _loversCallExists =>
      _extra.lovers.length == 2 &&
      _extra.lovers.keys.every(alive.contains) &&
      (_expanded.loversEdition == 'intense' &&
              !_expanded.loversMeetingDone &&
              _expanded.loversMeetingNight == night ||
          _expanded.loversEdition == 'horror' &&
              !_expanded.loversDeclined &&
              !_variantSpent.contains('${_expanded.loversSource}:break_pact'));

  void _openInitialLoversMeeting(String action) {
    if (action == 'lovers' &&
        _expanded.loversEdition == 'intense' &&
        !_expanded.loversMeetingDone &&
        _expanded.loversMeetingNight == night) {
      _expanded.loversMeetingDone = true;
      _expanded.bondChats['lovers'] = _BondChannel(
        'lovers',
        _extra.lovers.keys.toSet(),
        remainingMilliseconds,
      );
    }
  }

  List<Map<String, dynamic>> _bondAbilities(String id) {
    if (!alive.contains(id) || !_powerEnabled(id)) return [];
    if (phase == 'lovers' &&
        _expanded.loversEdition == 'horror' &&
        _extra.lovers.containsKey(id) &&
        !_expanded.loversDeclined &&
        !_expanded.loversAgreed.contains(id) &&
        !_variantSpent.contains('${_expanded.loversSource}:break_pact')) {
      return [
        _expandedChoice(
          'lovers.break_agree',
          'Accepter de rompre le pacte · nos deux votes du jour seront perdus',
          [],
          0,
        ),
        _expandedChoice(
          'lovers.break_decline',
          'Conserver notre lien amoureux',
          [],
          0,
        ),
      ];
    }
    if (phase == 'sisters' &&
        roles[id] == 'sisters' &&
        _livingSisters.length == 2) {
      final actions = <Map<String, dynamic>>[];
      if (_sisterSource('intense', 'sister_chat') != null &&
          !_expanded.sistersDeclined &&
          !_expanded.sistersChatAgreed.contains(id)) {
        actions.add(
          _expandedChoice(
            'sisters.chat_agree',
            'Accepter notre échange privé de 60 secondes · une fois pour cette carte',
            [],
            0,
          ),
        );
        actions.add(
          _expandedChoice(
            'sisters.chat_decline',
            'Refuser cette rencontre privée',
            [],
            0,
          ),
        );
      }
      if (_sisterSource('horror', 'sister_transfer') != null) {
        actions.add(
          _expandedChoice(
            'sisters.transfer_agree',
            'Choisir ensemble la sœur dont une attaque sera transférée à l’autre cette nuit',
            _livingSisters,
            1,
          ),
        );
      }
      return actions;
    }
    return [];
  }

  bool _actBondVariant(String id, Map<String, dynamic> action) {
    final ability = _bondAbilities(
      id,
    ).where((a) => a['action'] == action['action']).firstOrNull;
    if (ability == null) return false;
    final chosen = _variantTargets(
      action,
      (ability['targets'] as List).cast<String>(),
      ability['min'] as int,
    );
    switch (action['action']) {
      case 'lovers.break_agree':
        _expanded.loversAgreed.add(id);
        if (_extra.lovers.keys.every(_expanded.loversAgreed.contains)) {
          final pair = _extra.lovers.keys.toList();
          _variantSpent.add('${_expanded.loversSource}:break_pact');
          for (final partner in pair) {
            _expanded.deniedVotes[partner] = night;
            _notice(
              partner,
              'Votre pacte est rompu d’un commun accord. Vos morts ne sont plus liées et vous perdez tous les deux le scrutin de condamnation du jour.',
            );
          }
          _extra.lovers.clear();
        }
      case 'lovers.break_decline':
        _expanded.loversDeclined = true;
      case 'sisters.chat_agree':
        _expanded.sistersChatAgreed.add(id);
        if (_livingSisters.every(_expanded.sistersChatAgreed.contains)) {
          for (final source in _livingSisters.where(
            (p) => editionOf(p) == 'intense',
          )) {
            _spend(source, 'sister_chat');
          }
          _expanded.bondChats['sisters'] = _BondChannel(
            'sisters',
            _livingSisters.toSet(),
            remainingMilliseconds,
          );
        }
      case 'sisters.chat_decline':
        _expanded.sistersDeclined = true;
      case 'sisters.transfer_agree':
        _expanded.sistersTransferVotes[id] = chosen.single;
        if (_livingSisters.every(
          (p) => _expanded.sistersTransferVotes[p] == chosen.single,
        )) {
          for (final source in _livingSisters.where(
            (p) => editionOf(p) == 'horror',
          )) {
            _spend(source, 'sister_transfer');
          }
          _expanded.sisterRedirect = (
            from: chosen.single,
            to: _livingSisters.singleWhere((p) => p != chosen.single),
          );
          _countNightTarget(chosen.single);
          for (final sister in _livingSisters) {
            _notice(
              sister,
              'Votre serment est confirmé : une attaque de la meute visant la sœur choisie sera transférée à l’autre cette nuit.',
            );
          }
        }
    }
    return true;
  }

  int _bondRemaining(_BondChannel channel) =>
      (channel.duration - (channel.startRemaining - remainingMilliseconds))
          .clamp(0, 60000);
  Map<String, dynamic>? _bondPrivate(String id) {
    final channel = _expanded.bondChats[phase];
    if (channel == null ||
        !alive.contains(id) ||
        !channel.members.contains(id) ||
        _bondRemaining(channel) <= 0 ||
        closed)
      return null;
    return {
      'kind': channel.kind,
      'members': channel.members.toList(),
      'remaining_ms': _bondRemaining(channel),
      'open': !paused,
      'messages': [for (final message in channel.messages) Map.of(message)],
    };
  }

  void _sendBondMessage(String id, dynamic text, {dynamic replyTo}) {
    final chat = _bondPrivate(id);
    if (chat == null || chat['open'] != true)
      throw StateError('Cet échange privé est fermé pour vous.');
    _chat(id, text, _expanded.bondChats[phase]!.messages, replyTo: replyTo);
  }

  String? _redirectSisterAttack(String? target) {
    final redirect = _expanded.sisterRedirect;
    if (redirect == null ||
        redirect.from != target ||
        !alive.contains(redirect.to))
      return target;
    _expanded.sisterRedirect = null;
    _countNightTarget(redirect.to);
    _log('effect', {
      'effect': 'sister_redirect',
      'target': redirect.from,
      'recipient': redirect.to,
    });
    return redirect.to;
  }
}
