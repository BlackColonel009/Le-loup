part of 'night_game.dart';

extension _VillageVariants on NightGame {
  bool _hasNightProtection(String id) =>
      !_cannotProtect(id) &&
      (id == _extra.protected ||
          _expanded.hunterWards.contains(id) ||
          _powerEnabled(id) && _expanded.elderGifts.contains(id) ||
          roles[id] == 'elder' &&
              _powerEnabled(id) &&
              !_extra.elderHit.contains(id) ||
          _expanded.presages.entries.any(
            (e) =>
                e.value == id && alive.contains(e.key) && _powerEnabled(e.key),
          ) ||
          _expanded.sisterRedirect?.from == id);

  List<Map<String, dynamic>> _villageAbilities(String id) {
    if (!alive.contains(id) || !_powerEnabled(id)) return [];
    final others = alive.where((p) => p != id).toList();
    if (phase == 'elder_watch' && roles[id] == 'elder') {
      if (editionOf(id) == 'intense' &&
          !_extra.elderHit.contains(id) &&
          !_spent(id, 'elder_gift')) {
        return [
          _expandedChoice(
            'elder.transfer',
            'Transmettre ma résistance encore intacte',
            others.where((p) => !_cannotProtect(p)).toList(),
            1,
          ),
        ];
      }
      if (editionOf(id) == 'horror' && !_spent(id, 'presage')) {
        return [
          _expandedChoice(
            'elder.presage',
            'Prédire publiquement une victime de la meute cette nuit · une fois',
            alive.where((p) => !_cannotProtect(p)).toList(),
            1,
          ),
        ];
      }
    }
    if (phase == 'wolves' &&
        _variant(id, 'little_girl', 'horror') &&
        !_isWolf(id) &&
        !_spent(id, 'false_whisper')) {
      return [
        {
          ..._expandedChoice(
            'little_girl.false_whisper',
            'Déposer un faux murmure anonyme · risque de détection : 1 sur 2',
            [],
            0,
          ),
          'text_input': true,
        },
      ];
    }
    return [];
  }

  bool _actVillageVariant(String id, Map<String, dynamic> action) {
    final ability = _villageAbilities(
      id,
    ).where((a) => a['action'] == action['action']).firstOrNull;
    if (ability == null) return false;
    final chosen = _variantTargets(
      action,
      (ability['targets'] as List).cast<String>(),
      ability['min'] as int,
    );
    switch (action['action']) {
      case 'elder.transfer':
        _spend(id, 'elder_gift');
        _extra.elderHit.add(id);
        _expanded.elderGifts.add(chosen.single);
        _notice(
          chosen.single,
          'Une résistance de l’Ancien vous a été transmise : elle peut arrêter une attaque de la meute.',
        );
      case 'elder.presage':
        _spend(id, 'presage');
        _expanded.presages[id] = chosen.single;
      case 'little_girl.false_whisper':
        final text = action['text'];
        if (text is! String || text.trim().isEmpty || text.length > 260) {
          throw ArgumentError('Écrivez un faux murmure de 1 à 260 caractères.');
        }
        final message = <Map<String, String>>[];
        _chat(id, text, message);
        _wolfMessages.add({
          'id': message.single['id']!,
          'author': 'unknown',
          'text': '[Présence inconnue] ${message.single['text']}',
        });
        if (_wolfMessages.length > 100) _wolfMessages.removeAt(0);
        _spend(id, 'false_whisper');
        if (_chanceDraw(2) == 0) _extra.spotted.add(id);
    }
    return true;
  }

  bool _blockByElderVariant(String id) {
    if (_cannotProtect(id)) return false;
    if (_powerEnabled(id) && _expanded.elderGifts.remove(id)) {
      _log('effect', {'effect': 'inherited_resistance', 'target': id});
      return true;
    }
    final prophet = _expanded.presages.entries
        .where(
          (e) => e.value == id && alive.contains(e.key) && _powerEnabled(e.key),
        )
        .firstOrNull;
    if (prophet == null) return false;
    _extra.elderHit.add(prophet.key);
    _expanded.presages.remove(prophet.key);
    _log('effect', {
      'effect': 'presage_saved',
      'actor': prophet.key,
      'target': id,
    });
    return true;
  }
}
