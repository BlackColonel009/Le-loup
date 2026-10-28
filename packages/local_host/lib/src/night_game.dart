import 'dart:math';
import 'dart:collection';
import 'village_weather.dart';
import 'role_rules.dart';
import 'narration_lines.g.dart';
import 'chat_stickers.g.dart';
part 'night_roles.dart';

/// Moteur autoritaire, indépendant du transport et de Flutter.
class NightGame {
  NightGame(
    Map<String, String> roles, {
    this.campOnly = false,
    this.revealOnDeath = true,
    DateTime Function()? clock,
    int Function(int)? weatherDraw,
    int Function(int)? chanceDraw,
    List<String>? sentenceOptions,
  }) : _roles = Map.of(roles),
       sentenceOptions = List.unmodifiable(sentenceOptions ?? sentences),
       alive = roles.keys.toSet(),
       _clock = clock ?? (() => DateTime.now().toUtc()),
       _weatherDraw = weatherDraw ?? Random.secure().nextInt,
       _chanceDraw = chanceDraw ?? Random.secure().nextInt {
    _recordNarration('role_reveal');
  }

  final Map<String, String> _roles;
  final List<String> sentenceOptions;
  Map<String, String> get roles => UnmodifiableMapView(_roles);
  final _RoleState _extra = _RoleState();
  final int Function(int) _chanceDraw;
  final Set<String> alive;
  final bool campOnly;
  final bool revealOnDeath;
  final List<Map<String, dynamic>> _deathEvents = [];
  final List<Map<String, dynamic>> _history = [];
  void _log(String kind, Map<String, dynamic> details) {
    _history.add({
      'kind': kind,
      'night': night,
      'phase': phase,
      'at': _clock().toIso8601String(),
      ...details,
    });
  }

  Map<String, dynamic>? _sentence;
  static const sentences = [
    'Guillotine',
    'Pilori',
    'Bannissement',
    'Cachot',
    'Échafaud',
    'Exil',
    'Jugement',
    'Gibet',
  ];

  int get sentenceRemaining => _sentence == null
      ? 0
      : (DateTime.parse(_sentence!['started_at'] as String)
                .add(const Duration(milliseconds: 4500))
                .difference(_clock())
                .inMilliseconds)
            .clamp(0, 4500);

  void spinSentence(int index) {
    if (_voteSummary?['eliminated'] == null ||
        !['hunter', 'scapegoat', 'vote_result', 'ended'].contains(phase)) {
      throw StateError(
        'Une sentence est réservée à un joueur éliminé par le vote.',
      );
    }
    if (_sentence != null) throw StateError('La sentence est déjà tirée.');
    if (index < 0 || index >= sentenceOptions.length)
      throw ArgumentError('Sentence inconnue.');
    _sentence = {
      'id': 'sentence-$night',
      'target': _voteSummary!['eliminated'],
      'index': index,
      'label': sentenceOptions[index],
      'started_at': _clock().toIso8601String(),
      'duration_ms': 4500,
    };
    _log('sentence', {
      'target': _sentence!['target'],
      'label': sentenceOptions[index],
    });
  }

  void _recordDeath(String id, String cause) {
    _log('death', {'target': id, 'cause': cause, 'role': roles[id]});
    _deathEvents.add({
      'id': 'death-${_deathEvents.length + 1}',
      'player': id,
      'cause': cause,
      'night': night,
    });
  }

  final DateTime Function() _clock;
  String phase = 'role_reveal';
  String? _sleepNarration;
  final List<Map<String, dynamic>> _narrationEvents = [];
  void _recordNarration(String cue) {
    if (!mdjNarrationLines.containsKey(cue)) return;
    _narrationEvents.add({
      'revision': revision,
      'cue': 'mdj_$cue.wav',
      'text': mdjNarrationLines[cue],
    });
    if (_narrationEvents.length > 32) _narrationEvents.removeAt(0);
  }

  int revision = 0;
  int night = 0;
  final int Function(int) _weatherDraw;
  String _nightWeather = 'clear';
  int _weatherSeed = 0;
  DateTime? _weatherStarted;

  Map<String, dynamic> get _publicWeather {
    final nighttime = _atNight;
    final weather = VillageWeather(
      kind: nighttime ? _nightWeather : 'clear',
      seed: _weatherSeed,
      night: night,
      rainbow: !nighttime && night > 0 && _nightWeather != 'clear',
    );
    return {
      'kind': weather.kind,
      'seed': weather.seed,
      'night': night,
      'rainbow': weather.rainbow,
      'elapsed_ms': _weatherStarted == null
          ? 0
          : _clock()
                .difference(_weatherStarted!)
                .inMilliseconds
                .clamp(0, 1 << 40),
    };
  }

  int durationSeconds = 120;
  DateTime? deadline;
  int? _pausedMilliseconds;
  bool closed = false;
  String? winner;
  final Map<String, String> _wolfChoices = {};
  final List<Map<String, String>> _wolfMessages = [];
  final Map<String, DateTime> _lastMessage = {};
  final Map<String, Map<String, String>> _visions = {};
  final Set<String> _witchDone = {};
  final Set<String> _nightCompleted = {};
  bool get _atNight => phase == 'sleep' || _nightCalls.containsKey(phase);
  bool _hasLivingRole(String role) =>
      alive.any((id) => roles[id] == role && _powerEnabled(id));
  List<Map<String, dynamic>> get nightActions => _buildNightActions();

  void callNight(String action) {
    if (phase != 'sleep' ||
        !nightActions.any(
          (a) => a['action'] == action && a['available'] == true,
        )) {
      throw StateError('Cet appel nocturne n’est pas disponible.');
    }
    _enter(action);
  }

  void finishNight() {
    if (phase != 'sleep')
      throw StateError(
        'Terminez l’appel en cours avant de réveiller le village.',
      );
    _dawn();
  }

  final Set<String> _lifeSpent = {};
  final Set<String> _deathSpent = {};
  String? _attack;
  String? _poison;
  bool _saved = false;
  String? _hunter;
  bool _hunterDone = false;
  List<String> deaths = [];
  final Map<String, String?> _votes = {};
  final List<Map<String, String>> _dayMessages = [];
  Map<String, dynamic>? _voteSummary;
  bool chatOpen = true;
  String _afterReactions = 'day';
  bool _dayComplete = false;

  void startVote({int seconds = 120}) {
    if (phase != 'day')
      throw StateError('Le vote se lance uniquement pendant le débat.');
    if (seconds < 15 || seconds > 600)
      throw ArgumentError('Durée entre 15 et 600 secondes.');
    _votes.clear();
    _voteSummary = null;
    _enter('voting');
    deadline = _clock().add(Duration(seconds: seconds));
  }

  void setChatOpen(bool value) {
    if (!['day', 'voting', 'vote_result'].contains(phase))
      throw StateError('Le chat général est réservé à la journée.');
    chatOpen = value;
  }

  bool get paused => _pausedMilliseconds != null;
  bool get timed =>
      (_atNight && phase != 'sleep') ||
      ['hunter', 'scapegoat', 'voting'].contains(phase);
  int get remainingMilliseconds => paused
      ? _pausedMilliseconds!
      : deadline == null
      ? 0
      : deadline!.difference(_clock()).inMilliseconds.clamp(0, 3600000);

  String get announcement =>
      _sleepNarration ??
      mdjNarrationLines[phase] ??
      switch (phase) {
        'role_reveal' => 'Découvrez votre rôle à l’abri des regards.',
        'sleep' => 'Le village s’endort. Fermez les yeux…',
        'seer' =>
          'Voyante, ouvre les yeux. Quelle identité souhaites-tu découvrir ?',
        'wolves' => 'Loups-Garous, réveillez-vous. Quelle sera votre victime ?',
        'witch' =>
          'Les loups se rendorment. Sorcière, réveille-toi et prépare tes potions.',
        'dawn' =>
          'Le jour se lève. Le village découvre les événements de la nuit.',
        'hunter' => 'Chasseur, ton dernier souffle te laisse un dernier tir.',
        'day' => 'Le village est réveillé. Place au débat.',
        'voting' =>
          'Le village vote. Désignez un joueur ou choisissez le vote blanc.',
        'vote_result' =>
          'Le scrutin est terminé. Le village découvre le résultat.',
        'ended' => _victoryAnnouncement(),
        _ => _extraAnnouncement(),
      };

  Map<String, dynamic> get publicState => {
    'narration_events': [for (final e in _narrationEvents) Map.of(e)],
    if (phase == 'ended')
      'history': [for (final event in _history) _copyHistory(event)],
    'phase': phase,
    'phase_revision': revision,
    'night': night,
    'is_night': _atNight,
    'timed': timed,
    'announcement': announcement,
    'night_menu': phase == 'sleep' && _nightCompleted.isNotEmpty,
    'weather': _publicWeather,
    'deadline': deadline?.toIso8601String(),
    'paused': paused,
    'remaining_ms': remainingMilliseconds,
    'closed': closed,
    'alive_ids': alive.toList(),
    'deaths': List<String>.of(deaths),
    'winner': winner,
    'winner_ids': List<String>.of(_extra.winners),
    'village_powers_lost': _extra.villagePowersLost,
    'chat_open': chatOpen,
    if (['day', 'voting', 'vote_result'].contains(phase))
      'day_messages': [for (final message in _dayMessages) Map.of(message)],
    if (phase == 'voting') 'votes_received': _votes.length,
    'vote_eligible_count': _eligibleVoters.length,
    if (_voteSummary != null) 'vote_result': Map.of(_voteSummary!),
    'reveal_roles_on_death': revealOnDeath,
    'sentence_options': sentenceOptions,
    'death_events': [
      for (final event in _deathEvents)
        {
          ...event,
          if (revealOnDeath || phase == 'ended') 'role': roles[event['player']],
        },
    ],
    if (_sentence != null)
      'sentence': {..._sentence!, 'remaining_ms': sentenceRemaining},
    if (phase == 'ended' || revealOnDeath || _extra.gracedIdiots.isNotEmpty)
      'revealed_roles': {
        for (final entry in roles.entries)
          if (phase == 'ended' ||
              (revealOnDeath && !alive.contains(entry.key)) ||
              _extra.gracedIdiots.contains(entry.key))
            entry.key: entry.value,
      },
  };

  Map<String, dynamic> privateState(String id) {
    final role = roles[id];
    final canAct =
        alive.contains(id) && !closed && !paused && remainingMilliseconds > 0;
    return {
      if (_latestSelection(id) != null)
        'confirmed_selection': _latestSelection(id),
      'id': id,
      'role': role,
      'phase_revision': revision,
      'alive': alive.contains(id),
      'can_vote': phase == 'voting' && canAct && _eligibleVoters.contains(id),
      if (['voting', 'vote_result'].contains(phase)) ...{
        'vote_submitted': _votes.containsKey(id),
        'vote_target': _votes[id],
      },
      'can_act':
          (phase == 'seer' && role == 'seer' && !_visions.containsKey(id) ||
                  phase == 'wolves' && _isWolf(id) ||
                  phase == 'witch' &&
                      role == 'witch' &&
                      !_witchDone.contains(id)) &&
              canAct &&
              _powerEnabled(id) ||
          phase == 'hunter' &&
              _hunter == id &&
              !_hunterDone &&
              !closed &&
              !paused &&
              remainingMilliseconds > 0,
      if (role == 'seer' && _visions[id] != null)
        'vision': Map.of(_visions[id]!),
      if (_isWolf(id) && alive.contains(id)) ...{
        'pack': [
          for (final entry in roles.entries)
            if (_isWolf(entry.key) && alive.contains(entry.key)) entry.key,
        ],
        if (phase == 'wolves') 'choices': Map.of(_wolfChoices),
        if (phase == 'wolves')
          'messages': [for (final message in _wolfMessages) Map.of(message)],
      },
      if (role == 'witch') ...{
        'life_available': !_lifeSpent.contains(id),
        'death_available': !_deathSpent.contains(id),
        'submitted': _witchDone.contains(id),
        if (phase == 'witch' && alive.contains(id) && !_lifeSpent.contains(id))
          'victim': _attack,
      },
      if (phase == 'hunter' && _hunter == id) 'hunter_done': _hunterDone,
      ..._additionalPrivate(id, canAct),
    };
  }

  Map<String, dynamic> get hostState => {
    'confirmed_selections': [
      for (final id in roles.keys)
        if (_latestSelection(id) != null) _latestSelection(id),
    ],
    ..._additionalHost,
    if (_atNight) 'night_actions': nightActions,
    'wolf_messages': [for (final message in _wolfMessages) Map.of(message)],
    'wolf_choices': Map.of(_wolfChoices),
    'victim': _attack,
    'visions': {
      for (final entry in _visions.entries) entry.key: Map.of(entry.value),
    },
    'witch_done': _witchDone.toList(),
    'saved': _saved,
    'potion_used': _saved || _poison != null,
    'poison': _poison,
    'pending_hunter': _hunter,
    'hunter_done': _hunterDone,
    'life_spent': _lifeSpent.toList(),
    'death_spent': _deathSpent.toList(),
  };

  void startNight({int seconds = 120}) {
    if (sentenceRemaining > 0)
      throw StateError('Patientez pendant la roue des sentences.');
    if (phase != 'role_reveal' && !(phase == 'vote_result' && _dayComplete))
      throw StateError('La nuit ne peut pas commencer ici.');
    if (seconds < 15 || seconds > 600)
      throw ArgumentError('Durée entre 15 et 600 secondes.');
    durationSeconds = seconds;
    night++;
    _startExtraNight();
    final weatherRoll = _weatherDraw(100);
    _nightWeather = weatherRoll < 18
        ? 'storm'
        : weatherRoll < 45
        ? 'rain'
        : 'clear';
    _weatherSeed = _weatherDraw(1 << 30);
    _weatherStarted = _clock();
    _wolfChoices.clear();
    _visions.clear();
    _witchDone.clear();
    _nightCompleted.clear();
    deaths = [];
    _wolfMessages.clear();
    _lastMessage.clear();
    _attack = null;
    _poison = null;
    _saved = false;
    _hunter = null;
    _hunterDone = false;
    _dayComplete = false;
    _votes.clear();
    _voteSummary = null;
    _sentence = null;
    _enter('sleep');
  }

  void _enter(String value) {
    final closing =
        value == 'sleep' && mdjNarrationLines.containsKey('close_$phase')
        ? 'close_$phase'
        : null;
    _sleepNarration = closing == null ? null : mdjNarrationLines[closing];
    phase = value;
    _log('phase', {'label': announcement});
    revision++;
    _recordNarration(closing ?? value);
    closed = false;
    _pausedMilliseconds = null;
    deadline = timed
        ? _clock().add(
            Duration(seconds: phase == 'hunter' ? 60 : durationSeconds),
          )
        : null;
  }

  bool expire() {
    if (timed && !paused && !closed && remainingMilliseconds == 0) {
      closed = true;
      return true;
    }
    return false;
  }

  void pause() {
    expire();
    if (!timed || paused || closed)
      throw StateError('Cet appel ne peut pas être suspendu.');
    _pausedMilliseconds = remainingMilliseconds;
    deadline = null;
  }

  void resume() {
    if (!paused) throw StateError('Le chronomètre n’est pas suspendu.');
    deadline = _clock().add(Duration(milliseconds: _pausedMilliseconds!));
    _pausedMilliseconds = null;
  }

  void advance() {
    if (sentenceRemaining > 0)
      throw StateError('Patientez pendant la roue des sentences.');
    if (paused)
      throw StateError('Reprenez le chronomètre avant de poursuivre.');
    switch (phase) {
      case 'sleep':
        throw StateError(
          'Choisissez un appel nocturne ou réveillez le village.',
        );
      case 'seer':
        _nightCompleted.add('seer');
        _enter('sleep');
      case 'wolves':
        final wolves = alive.where(_isWolf).toList();
        final targets = wolves.map((id) => _wolfChoices[id]).toSet();
        _attack =
            wolves.isNotEmpty && targets.length == 1 && targets.single != null
            ? targets.single
            : null;
        if (_attack == _extra.protected) _attack = null;
        _nightCompleted.add('wolves');
        _wolfMessages.clear();
        _enter('sleep');
      case 'witch':
        _nightCompleted.add('witch');
        _enter('sleep');
      case 'dawn':
        _beginReactions();
      case 'hunter':
        _hunter = null;
        _hunterDone = false;
        _beginReactions();
      case 'scapegoat':
        _extra.scapegoat = null;
        _beginReactions();
      case 'voting':
        _resolveVote();
      default:
        if (_nightCalls.containsKey(phase)) {
          _nightCompleted.add(phase);
          _enter('sleep');
        } else {
          throw StateError('Aucune transition disponible.');
        }
    }
  }

  void _dawn() {
    _afterReactions = 'day';
    deaths = [];
    _resolveExtraDeaths();
    _enter('dawn');
  }

  void _finish() {
    _resolveVictory();
    if (winner == null && _afterReactions == 'day') {
      _dayMessages.clear();
      chatOpen = true;
    }
    _enter(winner == null ? _afterReactions : 'ended');
  }

  void _resolveVote() {
    final eligible = _eligibleVoters.length;
    final counts = <String, int>{};
    var blank = 0;
    for (final target in _votes.values) {
      if (target == null) {
        blank++;
      } else {
        counts[target] = (counts[target] ?? 0) + 1;
      }
    }
    final best = [blank, ...counts.values].reduce((a, b) => a > b ? a : b);
    final leaders = counts.entries
        .where((entry) => entry.value == best)
        .map((entry) => entry.key)
        .toList();
    final blankLeads = blank == best;
    final tie = leaders.length + (blankLeads ? 1 : 0) > 1;
    var eliminated = best > 0 && !blankLeads && !tie ? leaders.single : null;
    var reason = best == 0
        ? 'abstention'
        : tie
        ? 'tie'
        : blankLeads
        ? 'blank'
        : 'elimination';
    final goat = alive
        .where((id) => roles[id] == 'scapegoat' && _powerEnabled(id))
        .firstOrNull;
    if (best > 0 && tie && goat != null) {
      eliminated = goat;
      reason = 'scapegoat';
    }
    final graced =
        eliminated != null &&
            roles[eliminated] == 'idiot' &&
            _powerEnabled(eliminated) &&
            !_extra.gracedIdiots.contains(eliminated)
        ? eliminated
        : null;
    if (graced != null) {
      _extra.gracedIdiots.add(graced);
      eliminated = null;
      reason = 'idiot_grace';
    }
    _voteSummary = {
      'counts': counts,
      'blank': blank,
      'abstentions': eligible - _votes.length,
      'eligible': eligible,
      'cast': _votes.length,
      'eliminated': eliminated,
      'reason': reason,
      if (graced != null) 'graced': graced,
    };
    _log('vote_result', {
      ..._voteSummary!,
      'ballots': Map.of(_votes),
      'abstained': _eligibleVoters
          .where((id) => !_votes.containsKey(id))
          .toList(),
    });
    if (!_extra.firstVoteResolved) {
      if (eliminated != null &&
          roles[eliminated] == 'angel' &&
          !_isWolf(eliminated))
        _extra.angelWinner = eliminated;
      _extra.firstVoteResolved = true;
      for (final id
          in alive
              .where((id) => roles[id] == 'angel' && id != eliminated)
              .toList()) {
        _roles[id] = 'villager';
        _log('effect', {'effect': 'angel_becomes_villager', 'target': id});
        _notice(
          id,
          'Le premier vote est passé : vous devenez Simple Villageois.',
        );
      }
    }
    deaths = [];
    if (eliminated != null) _kill({eliminated: 'vote'});
    _hunterDone = false;
    _dayComplete = true;
    _afterReactions = 'vote_result';
    _beginReactions();
  }

  void act(String id, Map<String, dynamic> action) {
    final event = <String, dynamic>{
      'kind': 'action',
      'night': night,
      'phase': phase,
      'phase_revision': revision,
      'at': _clock().toIso8601String(),
      'actor': id,
      'role': roles[id],
      for (final key in ['action', 'target', 'targets', 'save', 'kill'])
        if (action.containsKey(key))
          key: action[key] is List ? List.of(action[key]) : action[key],
      if (action['action'] == 'witch.potions') 'victim': _attack,
    };
    final position = _history.length;
    _act(id, action);
    // Record only accepted commands, never chat contents or failed attempts.
    if (!(action['action'] as String).endsWith('.chat')) {
      if (action['action'] == 'seer.inspect')
        event['vision'] = Map.of(_visions[id]!);
      if (action['action'] == 'metamorph.swap') {
        event['new_roles'] = {
          for (final target in action['targets'] as List) target: roles[target],
        };
      }
      if (action['action'] == 'little_girl.peek') {
        event['spotted'] = _extra.spotted.contains(id);
      }
      _history.insert(position, event);
    }
  }

  dynamic _copyHistory(dynamic value) => value is Map
      ? {for (final e in value.entries) e.key: _copyHistory(e.value)}
      : value is List
      ? value.map(_copyHistory).toList()
      : value;

  Map<String, dynamic>? _latestSelection(String id) {
    final event = _history.reversed
        .where(
          (e) =>
              e['kind'] == 'action' &&
              e['actor'] == id &&
              e['phase_revision'] == revision,
        )
        .firstOrNull;
    return event == null
        ? null
        : Map<String, dynamic>.from(_copyHistory(event) as Map);
  }

  void _act(String id, Map<String, dynamic> action) {
    expire();
    if (action['action'] == 'day.chat') {
      if (action['phase_revision'] != revision ||
          !alive.contains(id) ||
          !['day', 'voting', 'vote_result'].contains(phase) ||
          !chatOpen) {
        throw StateError('Le chat général est fermé pour vous.');
      }
      _chat(id, action['text'], _dayMessages);
      return;
    }
    if (action['phase_revision'] != revision ||
        paused ||
        closed ||
        !timed ||
        remainingMilliseconds == 0) {
      throw StateError('Cet appel est terminé ou suspendu.');
    }
    final role = roles[id];
    final target = action['target'];
    bool validTarget() =>
        target is String && target != id && alive.contains(target);
    if (phase == 'hunter' &&
        _hunter == id &&
        !_hunterDone &&
        action['action'] == 'hunter.shoot') {
      if (!validTarget())
        throw ArgumentError('Choisissez un autre joueur vivant.');
      _kill({target as String: 'hunter'});
      _hunterDone = true;
      return;
    }
    if (!alive.contains(id)) {
      if (_actExtra(id, action)) return;
      throw StateError('Un joueur éliminé ne peut plus agir.');
    }
    if (phase == 'voting' && action['action'] == 'vote.cast') {
      if (!_eligibleVoters.contains(id))
        throw StateError('Vous ne disposez pas du droit de vote.');
      if (target != null && (target is! String || !alive.contains(target))) {
        throw ArgumentError('Désignez un joueur vivant ou votez blanc.');
      }
      _votes[id] = target as String?;
      return;
    }
    if (phase == 'wolves' && _isWolf(id) && action['action'] == 'wolves.chat') {
      _chat(id, action['text'], _wolfMessages);
      return;
    }
    if (_actExtra(id, action)) return;
    if (!_powerEnabled(id)) throw StateError('Votre pouvoir est désactivé.');
    if (phase == 'seer' &&
        role == 'seer' &&
        action['action'] == 'seer.inspect' &&
        !_visions.containsKey(id)) {
      if (!validTarget())
        throw ArgumentError('Choisissez un autre joueur vivant.');
      _visions[id] = {
        'target': target as String,
        'kind': campOnly ? 'camp' : 'role',
        'value': campOnly ? _camp(target) : roles[target]!,
      };
    } else if (phase == 'wolves' &&
        _isWolf(id) &&
        action['action'] == 'wolves.choose') {
      if (!validTarget() || _isWolf(target))
        throw ArgumentError('Choisissez une victime hors de la meute.');
      _wolfChoices[id] = target as String;
    } else if (phase == 'witch' &&
        role == 'witch' &&
        action['action'] == 'witch.potions' &&
        !_witchDone.contains(id)) {
      final save = action['save'];
      final kill = action['kill'];
      if (save is! bool ||
          kill != null && (kill is! String || !alive.contains(kill)))
        throw ArgumentError('Choix de potions invalide.');
      if (save && (_attack == null || _lifeSpent.contains(id)))
        throw StateError('Potion de vie indisponible.');
      if (kill != null && _deathSpent.contains(id))
        throw StateError('Potion de mort indisponible.');
      if (save) {
        _lifeSpent.add(id);
        _saved = true;
      }
      if (kill != null) {
        _deathSpent.add(id);
        _poison = kill as String;
      }
      _witchDone.add(id);
    } else {
      throw StateError(
        'Ce pouvoir n’est pas autorisé pour vous pendant cet appel.',
      );
    }
  }

  void _chat(String id, dynamic text, List<Map<String, String>> messages) {
    if (text is! String || text.trim().isEmpty || text.length > 300)
      throw ArgumentError('Message de 1 à 300 caractères.');
    validateStickerMessage(text);
    if (_lastMessage[id] != null &&
        _clock().difference(_lastMessage[id]!).inMilliseconds < 1000) {
      throw StateError('Patientez une seconde entre deux messages.');
    }
    _lastMessage[id] = _clock();
    messages.add({'author': id, 'text': text.trim()});
    if (messages.length > 100) messages.removeAt(0);
  }
}
