import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'night_game.dart';
import 'card_variants.dart';
import 'role_rules.dart';
import 'game_host.dart';

class LocalHost implements GameHost {
  LocalHost({
    this.heartbeatInterval = const Duration(seconds: 30),
    this.reconnectGrace = const Duration(minutes: 2),
  });
  // Laisse davantage de marge aux émulateurs et aux appareils momentanément chargés.
  final Duration heartbeatInterval;
  final Duration reconnectGrace;
  final _reconnectExpiry = <String, Timer>{};
  HttpServer? _server;
  final _peers = HashMap<WebSocket, Map<String, dynamic>>.identity();
  final _pending = HashSet<WebSocket>.identity();
  final _diagnostics = <String>[];

  void _trace(String message) {
    _diagnostics.add(
      '${DateTime.now().toIso8601String().substring(11, 19)} · $message',
    );
    if (_diagnostics.length > 8) _diagnostics.removeAt(0);
  }

  final _players = <String, Map<String, dynamic>>{};
  final _tokens = <String, String>{};
  final _roles = <String, String>{};
  NightGame? _game;
  Timer? _phaseTimer;
  Timer? _sentenceTimer;

  void startNight({int seconds = 120}) {
    if (_game == null) throw StateError('Distribuez les rôles d’abord.');
    _game!.startNight(seconds: seconds);
    _gameChanged();
  }

  void startVote({int seconds = 120}) {
    _game!.startVote(seconds: seconds);
    _gameChanged();
  }

  void setDayChat(bool value) {
    _game!.setChatOpen(value);
    _gameChanged();
  }

  void advanceNight() {
    _game!.advance();
    _gameChanged();
  }

  void callNight(String action) {
    _game!.callNight(action);
    _gameChanged();
  }

  void finishNight() {
    _game!.finishNight();
    _gameChanged();
  }

  void pauseNight() {
    _game!.pause();
    _gameChanged();
  }

  void resumeNight() {
    _game!.resume();
    _gameChanged();
  }

  void _gameChanged() {
    _phaseTimer?.cancel();
    final game = _game;
    if (game != null && game.timed && !game.paused && !game.closed) {
      _phaseTimer = Timer(
        Duration(milliseconds: game.remainingMilliseconds),
        () {
          game.expire();
          _publish();
        },
      );
    }
    _publish();
  }

  void _sendGameState(WebSocket socket, String id) {
    if (_game != null && socket.readyState == WebSocket.open) {
      socket.add(
        jsonEncode({'type': 'game.private', ..._game!.privateState(id)}),
      );
    }
  }

  Map<String, int> _deck = {
    for (final id in roleIds) id: 0,
    'villager': 3,
    'werewolf': 1,
    'seer': 0,
    'witch': 0,
    'hunter': 0,
  };
  bool started = false;
  bool seerCampOnly = false;
  bool revealRolesOnDeath = true;
  bool revealRescuer = false;
  String narrationProfile = 'classic_male';
  bool automaticNarration = true;
  @override
  void setNarration({required String profile, required bool automatic}) {
    if (![
      'classic_male',
      'classic_female',
      'intense_male',
      'intense_female',
      'duke',
      'old_wizard',
      'old_witch',
      'werewolf',
      'ghost',
      'cold_killer',
    ].contains(profile)) {
      throw ArgumentError('Profil de voix inconnu.');
    }
    narrationProfile = profile;
    automaticNarration = automatic;
    _publish();
  }

  void spinSentence() {
    if (_game == null) throw StateError('Aucune partie en cours.');
    _game!.spinSentence(_random.nextInt(sentenceOptions.length));
    _scheduleSentenceEnd();
    _publish();
  }

  void _scheduleSentenceEnd() {
    _sentenceTimer?.cancel();
    if (_game == null) return;
    _sentenceTimer = Timer(
      Duration(milliseconds: _game!.sentenceRemaining + 1),
      () {
        if (_game == null) return;
        if (_game!.sentenceRemaining > 0) {
          _scheduleSentenceEnd();
        } else {
          _publish();
        }
      },
    );
  }

  void continueAfterSentence() {
    final game = _game;
    if (game == null || game.publicState['sentence'] == null) {
      throw StateError('Aucune sentence à poursuivre.');
    }
    if (game.phase != 'vote_result') {
      throw StateError(
        'Résolvez la réaction en cours ou consultez le résultat de la partie.',
      );
    }
    startNight(seconds: game.durationSeconds);
  }

  Map<String, int> get deck => Map.unmodifiable(_deck);
  String _visualPack = 'classic';
  Map<String, String> _cardStyles = {};
  String get visualPack => _visualPack;
  List<String> _sentenceOptions = List.of(NightGame.sentences);
  List<String> get sentenceOptions => List.unmodifiable(_sentenceOptions);
  String _secret() => List.generate(
    32,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  void configure(
    Map<String, int> deck, {
    required bool campOnly,
    bool? revealOnDeath,
    bool? revealRescuer,
    String? pack,
    List<String>? sentences,
    Map<String, String>? cardStyles,
  }) {
    if (started) throw StateError('La partie a déjà commencé.');
    if (cardStyles != null &&
        (cardStyles.keys.any((key) {
              final parts = key.split('#');
              final id = parts.first;
              if (!roleIds.contains(id) && id != 'mayor') return true;
              if (parts.length == 1) return false;
              final index = parts.length == 2 ? int.tryParse(parts[1]) : null;
              return index == null || index < 0 || index >= (deck[id] ?? 0);
            }) ||
            cardStyles.values.any(
              (style) => !['classic', 'intense', 'horror'].contains(style),
            )))
      throw ArgumentError('Habillage de carte invalide.');
    if (pack != null && !['classic', 'intense', 'horror'].contains(pack)) {
      throw ArgumentError('Pack inconnu ou indisponible.');
    }
    if (sentences != null &&
        (sentences.length != 8 ||
            sentences.any((s) => s.trim().isEmpty || s.trim().length > 32))) {
      throw ArgumentError('Indiquez huit sentences de 1 à 32 caractères.');
    }
    if (![
          'villager',
          'werewolf',
          'seer',
          'witch',
          'hunter',
        ].every(deck.containsKey) ||
        !deck.keys.every(roleIds.contains) ||
        deck.values.any((n) => n < 0 || n > 20) ||
        ![0, 2].contains(deck['sisters'] ?? 0) ||
        deck.entries.any(
          (entry) =>
              !['villager', 'werewolf', 'sisters'].contains(entry.key) &&
              entry.value > 1,
        )) {
      throw ArgumentError(
        'Composition invalide. Les rôles spéciaux sont uniques.',
      );
    }
    _deck = {for (final id in roleIds) id: deck[id] ?? 0};
    seerCampOnly = campOnly;
    if (pack != null) {
      if (pack != _visualPack && cardStyles == null) _cardStyles = {};
      _visualPack = pack;
    }
    if (cardStyles != null) _cardStyles = Map.of(cardStyles);
    _cardStyles.removeWhere((key, _) {
      final parts = key.split('#');
      return parts.first != 'mayor' &&
          ((_deck[parts.first] ?? 0) == 0 ||
              parts.length == 2 &&
                  int.parse(parts[1]) >= (_deck[parts.first] ?? 0));
    });
    if (sentences != null)
      _sentenceOptions = sentences.map((s) => s.trim()).toList();
    if (revealOnDeath != null) revealRolesOnDeath = revealOnDeath;
    if (revealRescuer != null) this.revealRescuer = revealRescuer;
    // Une modification nécessite une nouvelle confirmation des joueurs.
    for (final player in _players.values) {
      player['ready'] = player['is_bot'] == true;
    }
    _publish();
  }

  String? get launchError {
    if (started) return 'La distribution a déjà eu lieu.';
    if (_players.length < 4) return 'Il faut au moins 4 joueurs, hors MDJ.';
    if (_deck.values.fold(0, (a, b) => a + b) != _players.length)
      return 'Il faut exactement une carte par joueur.';
    final predators = wolfRoleIds.fold(0, (sum, id) => sum + (_deck[id] ?? 0));
    if (predators < 1 || predators * 2 >= _players.length)
      return 'Il faut au moins un loup et une majorité de villageois.';
    if (_players.values.any(
          (p) =>
              p['ready'] != true ||
              (p['connected'] != true && p['background'] != true),
        ) ||
        _peers.keys.any((socket) => socket.readyState != WebSocket.open))
      return 'Tous les joueurs doivent être connectés et prêts.';
    return null;
  }

  /// Host-only metadata: never accepted as a command from a joining player.
  bool _testMode = false;
  void markTestPlayer(String id) => markBotPlayer(id);
  void markBotPlayer(String id, {bool practice = true}) {
    if (started || !_players.containsKey(id)) {
      throw StateError('Joueur de test indisponible.');
    }
    if (practice) _testMode = true;
    _players[id]!['is_bot'] = true;
    _players[id]!['ready'] = true;
    _publish();
  }

  bool _botsPaused = false;
  int _botDelay = 900;
  void setBotControls({required bool paused, required int delayMilliseconds}) {
    _botsPaused = paused;
    _botDelay = delayMilliseconds;
    _publish();
  }

  void startGame() {
    final error = launchError;
    if (error != null) throw StateError(error);
    final cards = [
      for (final entry in _deck.entries)
        for (var i = 0; i < entry.value; i++)
          (entry.key, cardEdition(_cardStyles, entry.key, i, _visualPack)),
    ]..shuffle(_random);
    var index = 0;
    final editions = <String, String>{};
    for (final id in _players.keys) {
      final card = cards[index++];
      _roles[id] = card.$1;
      editions[id] = card.$2;
    }
    started = true;
    for (final timer in _reconnectExpiry.values) {
      timer.cancel();
    }
    _reconnectExpiry.clear();
    _game = NightGame(
      _roles,
      electMayor: true,
      editions: editions,
      campOnly: seerCampOnly,
      revealOnDeath: revealRolesOnDeath,
      revealRescuer: revealRescuer,
      sentenceOptions: sentenceOptions,
    );
    locked = true;
    _publish();
    for (final entry in _peers.entries) {
      _sendRole(entry.key, entry.value['id'] as String);
    }
  }

  void _sendRole(WebSocket socket, String id) {
    if (_roles.containsKey(id) && socket.readyState == WebSocket.open) {
      socket.add(
        jsonEncode({
          'type': 'game.role',
          'role': _roles[id],
          'seer_camp_only': seerCampOnly,
        }),
      );
    }
  }

  void _depart(WebSocket socket, {Object? error}) {
    _pending.remove(socket);
    final player = _peers.remove(socket);
    if (player == null) return;
    final id = player['id'] as String;
    _trace(
      'Déconnexion de ${player['nickname']} · code ${socket.closeCode ?? 'absent'}'
      '${socket.closeReason == null ? '' : ' · ${socket.closeReason}'}'
      '${error == null ? '' : ' · $error'}',
    );
    if (started) {
      player['connected'] = false;
    } else {
      // A transport interruption is not a deliberate departure. Preserve the
      // seat, alias, ready confirmation and resume token for a short grace.
      player['connected'] = false;
      _reconnectExpiry.remove(id)?.cancel();
      _reconnectExpiry[id] = Timer(reconnectGrace, () {
        _reconnectExpiry.remove(id);
        if (!started && player['connected'] != true) {
          _players.remove(id);
          _tokens.removeWhere((_, value) => value == id);
          _publish();
        }
      });
    }
    _publish();
  }

  final _updates = StreamController<Map<String, dynamic>>.broadcast();
  final _random = Random.secure();
  bool locked = false;
  String code = '';
  String nickname = '';
  int? get port => _server?.port;
  Stream<Map<String, dynamic>> get updates => _updates.stream;

  Map<String, dynamic> get publicSnapshot => {
    'test_mode': _testMode,
    'has_bots': _players.values.any((p) => p['is_bot'] == true),
    'bot_count': _players.values.where((p) => p['is_bot'] == true).length,
    'type': 'room.snapshot',
    'version': 1,
    'code': code,
    'host': nickname,
    'visual_pack': visualPack,
    'card_styles': Map.of(_cardStyles),
    'pack_label': _cardStyles.values.any((style) => style != visualPack)
        ? 'mixed'
        : visualPack,
    'narration_profile': narrationProfile,
    'automatic_narration': automaticNarration,
    'sentence_options': List.of(sentenceOptions),
    'locked': locked,
    'phase': _game?.phase ?? (started ? 'role_reveal' : 'lobby'),
    if (_game != null)
      'game': {
        ..._game!.publicState,
        if (visualPack == 'intense')
          'weather': {
            ...(_game!.publicState['weather'] as Map),
            'kind': 'snow',
            'rainbow': false,
          },
      },
    'deck': Map.of(_deck),
    'seer_camp_only': seerCampOnly,
    'reveal_roles_on_death': revealRolesOnDeath,
    'reveal_rescuer': revealRescuer,
    'players': [for (final p in _players.values) Map<String, dynamic>.of(p)],
  };

  // Réservé au MDJ, jamais diffusé sur les sockets des joueurs.
  Map<String, dynamic> get snapshot => {
    'bots_paused': _botsPaused,
    'bot_delay_ms': _botDelay,
    ...publicSnapshot,
    'assignments': Map.of(_roles),
    if (_game != null) 'game_host': _game!.hostState,
    'launch_error': launchError,
    'connection_diagnostics': List<String>.of(_diagnostics),
  };

  Future<List<String>> addresses() async => [
    for (final interface in await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    ))
      for (final address in interface.addresses)
        if (!address.isLoopback) '${address.address}:$port',
  ];

  Future<void> start({
    int port = 8080,
    String nickname = 'MDJ',
    String? bindAddress,
  }) async {
    if (_server != null) throw StateError('Le serveur est déjà démarré.');
    if (nickname.trim().isEmpty || nickname.trim().length > 24) {
      throw ArgumentError('Le pseudo doit contenir entre 1 et 24 caractères.');
    }
    this.nickname = nickname.trim();
    code = '${100000 + _random.nextInt(900000)}';
    _testMode = false;
    locked = false;
    started = false;
    _server = await HttpServer.bind(
      bindAddress == null
          ? InternetAddress.anyIPv4
          : InternetAddress(bindAddress),
      port,
    );
    _server!.listen(_handle);
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      if (request.uri.path == '/ws' &&
          WebSocketTransformer.isUpgradeRequest(request)) {
        if (_peers.length + _pending.length >= 24) {
          request.response.statusCode = 503;
          await request.response.close();
          return;
        }
        final socket = await WebSocketTransformer.upgrade(request);
        _pending.add(socket);
        socket.pingInterval = heartbeatInterval;
        final timeout = Timer(const Duration(seconds: 10), () {
          if (_pending.remove(socket)) socket.close(1008, 'Connexion expirée');
        });
        socket.listen(
          (raw) => _receive(socket, raw),
          onDone: () {
            timeout.cancel();
            _depart(socket);
          },
          onError: (Object error) {
            timeout.cancel();
            _depart(socket, error: error);
          },
        );
        return;
      }
      request.response.headers.contentType = ContentType.json;
      if (request.method == 'GET' && request.uri.path == '/health') {
        request.response.write(
          jsonEncode({
            'status': 'ok',
            'service': 'mordeviel-local',
            'protocol': '1',
          }),
        );
      } else {
        request.response.statusCode = 404;
        request.response.write(jsonEncode({'error': 'not_found'}));
      }
      await request.response.close();
    } catch (_) {
      // Une connexion interrompue ne doit pas arrêter le salon.
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  void _receive(WebSocket socket, dynamic raw) {
    void error(String message, {String? code}) => socket.add(
      jsonEncode({
        'type': 'error',
        'message': message,
        if (code != null) 'code': code,
      }),
    );
    try {
      if (raw is! String || raw.length > 4096) {
        socket.close(1009, 'Message trop volumineux');
        return;
      }
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['version'] != 1) {
        error('Version de protocole incompatible.');
        return;
      }
      if (data['type'] == 'room.resume' && !_peers.containsKey(socket)) {
        final id = _tokens[data['token']];
        if (data['code'] != code || id == null || !_players.containsKey(id)) {
          error(
            'Session inconnue. Le salon a peut-être été fermé.',
            code: 'resume_missing',
          );
          return;
        }
        final player = _players[id]!;
        if (player['connected'] == true) {
          error(
            'Cette session est encore connectée. Réessaie dans quelques secondes.',
            code: 'resume_busy',
          );
          return;
        }
        _pending.remove(socket);
        _reconnectExpiry.remove(id)?.cancel();
        player['connected'] = true;
        _peers[socket] = player;
        _trace('Reconnexion de ${player['nickname']}');
        socket.add(
          jsonEncode({'type': 'room.joined', 'id': id, 'token': data['token']}),
        );
        _publish();
        _sendRole(socket, id);
        _sendGameState(socket, id);
      } else if (data['type'] == 'room.join' && !_peers.containsKey(socket)) {
        final name = (data['nickname'] as String? ?? '').trim();
        final appearance = data['appearance'] ?? 'male';
        if (!['male', 'female'].contains(appearance)) {
          error('Choisissez une apparence Villageois ou Villageoise.');
          return;
        }
        if (locked || started) {
          error('Les inscriptions sont fermées.');
          return;
        }
        if (data['code'] != code) {
          error('Code de salon incorrect.');
          return;
        }
        if (name.isEmpty || name.length > 24) {
          error('Pseudo requis, 24 caractères maximum.');
          return;
        }
        if (name.toLowerCase() == nickname.toLowerCase() ||
            _players.values.any(
              (p) =>
                  (p['nickname'] as String).toLowerCase() == name.toLowerCase(),
            )) {
          error('Ce pseudo est déjà utilisé.');
          return;
        }
        if (_players.length >= 20) {
          error('Le salon est complet.');
          return;
        }
        final id = List.generate(
          16,
          (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
        _pending.remove(socket);
        final player = {
          'id': id,
          'nickname': name,
          'appearance': appearance,
          'ready': false,
          'connected': true,
          'background': false,
          'house_slot': List.generate(20, (index) => index).firstWhere(
            (slot) =>
                !_players.values.any((player) => player['house_slot'] == slot),
          ),
        };
        _peers[socket] = player;
        _players[id] = player;
        _trace('Arrivée de $name · ${_players.length} joueurs');
        final token = _secret();
        _tokens[token] = id;
        socket.add(
          jsonEncode({'type': 'room.joined', 'id': id, 'token': token}),
        );
        _publish();
      } else if (data['type'] == 'player.background' &&
          _peers.containsKey(socket) &&
          data['background'] is bool) {
        _peers[socket]!['background'] = data['background'];
        _publish();
      } else if (data['type'] == 'room.leave' && _peers.containsKey(socket)) {
        final player = _peers.remove(socket)!;
        final id = player['id'] as String;
        if (started) {
          player['connected'] = false;
          player['background'] = false;
        } else {
          _players.remove(id);
          _tokens.removeWhere((_, value) => value == id);
          _reconnectExpiry.remove(id)?.cancel();
        }
        _publish();
        socket.close(1000, 'Vous avez quitté le salon.');
      } else if (data['type'] == 'player.ready' &&
          _peers.containsKey(socket) &&
          !started &&
          data['ready'] is bool) {
        final player = _peers[socket]!;
        player['ready'] = player['is_bot'] == true || data['ready'] == true;
        _publish();
      } else if (data['type'] == 'game.action' &&
          _peers.containsKey(socket) &&
          _game != null) {
        try {
          _game!.act(_peers[socket]!['id'] as String, data);
          _publish();
        } on StateError catch (failure) {
          error(failure.message.toString());
        } on ArgumentError catch (failure) {
          error(failure.message.toString());
        }
      } else {
        error('Action non autorisée.');
      }
    } catch (_) {
      error('Message invalide.');
    }
  }

  void setLocked(bool value) {
    if (started) throw StateError('La partie est déjà lancée.');
    locked = value;
    _publish();
  }

  Future<void> kick(String id) async {
    if (started)
      throw StateError(
        'Impossible de retirer un joueur après la distribution.',
      );
    _players.remove(id);
    _reconnectExpiry.remove(id)?.cancel();
    _tokens.removeWhere((_, value) => value == id);
    final sockets = _peers.keys.where((s) => _peers[s]!['id'] == id).toList();
    for (final socket in sockets) {
      _peers.remove(socket);
      await socket.close(4001, 'Vous avez été retiré du salon.');
    }
    _publish();
  }

  void _publish() {
    if (_game != null) {
      _roles
        ..clear()
        ..addAll(_game!.roles);
    }
    final encoded = jsonEncode(publicSnapshot);
    for (final peer in _peers.keys.toList()) {
      if (peer.readyState == WebSocket.open) {
        peer.add(encoded);
        _sendGameState(peer, _peers[peer]!['id'] as String);
      }
    }
    _updates.add(snapshot);
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    final sockets = {..._pending, ..._peers.keys};
    _pending.clear();
    _peers.clear();
    _players.clear();
    for (final timer in _reconnectExpiry.values) {
      timer.cancel();
    }
    _reconnectExpiry.clear();
    _tokens.clear();
    _roles.clear();
    _phaseTimer?.cancel();
    _sentenceTimer?.cancel();
    _game = null;
    for (final socket in sockets) {
      await socket.close(1001, 'Le MDJ a fermé le salon.');
    }
    await server?.close(force: true);
  }

  Future<void> dispose() async {
    await stop();
    await _updates.close();
  }
}
