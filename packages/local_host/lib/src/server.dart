import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

class LocalHost {
  LocalHost({this.heartbeatInterval = const Duration(seconds: 30)});
  // Laisse davantage de marge aux émulateurs et aux appareils momentanément chargés.
  final Duration heartbeatInterval;
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
  Map<String, int> _deck = {
    'villager': 3,
    'werewolf': 1,
    'seer': 0,
    'witch': 0,
    'hunter': 0,
  };
  bool started = false;
  bool seerCampOnly = false;

  Map<String, int> get deck => Map.unmodifiable(_deck);
  String _secret() => List.generate(
    32,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  void configure(Map<String, int> deck, {required bool campOnly}) {
    if (started) throw StateError('La partie a déjà commencé.');
    if (deck.length != _deck.length ||
        !deck.keys.every(_deck.containsKey) ||
        deck.values.any((n) => n < 0 || n > 20) ||
        ['seer', 'witch', 'hunter'].any((key) => deck[key]! > 1)) {
      throw ArgumentError(
        'Composition invalide. Les rôles spéciaux sont uniques.',
      );
    }
    _deck = Map.of(deck);
    seerCampOnly = campOnly;
    // Une modification nécessite une nouvelle confirmation des joueurs.
    for (final player in _players.values) {
      player['ready'] = false;
    }
    _publish();
  }

  String? get launchError {
    if (started) return 'La distribution a déjà eu lieu.';
    if (_players.length < 4) return 'Il faut au moins 4 joueurs, hors MDJ.';
    if (_deck.values.fold(0, (a, b) => a + b) != _players.length)
      return 'Il faut exactement une carte par joueur.';
    if (_deck['werewolf']! < 1 || _deck['werewolf']! * 2 >= _players.length)
      return 'Il faut au moins un loup et une majorité de villageois.';
    if (_players.values.any(
          (p) => p['connected'] != true || p['ready'] != true,
        ) ||
        _peers.keys.any((socket) => socket.readyState != WebSocket.open))
      return 'Tous les joueurs doivent être connectés et prêts.';
    return null;
  }

  void startGame() {
    final error = launchError;
    if (error != null) throw StateError(error);
    final cards = [
      for (final entry in _deck.entries)
        for (var i = 0; i < entry.value; i++) entry.key,
    ]..shuffle(_random);
    var index = 0;
    for (final id in _players.keys) {
      _roles[id] = cards[index++];
    }
    started = true;
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
      _players.remove(id);
      _tokens.removeWhere((_, value) => value == id);
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
    'type': 'room.snapshot',
    'version': 1,
    'code': code,
    'host': nickname,
    'locked': locked,
    'phase': started ? 'role_reveal' : 'lobby',
    'deck': Map.of(_deck),
    'seer_camp_only': seerCampOnly,
    'players': [for (final p in _players.values) Map<String, dynamic>.of(p)],
  };

  // Réservé au MDJ, jamais diffusé sur les sockets des joueurs.
  Map<String, dynamic> get snapshot => {
    ...publicSnapshot,
    'assignments': Map.of(_roles),
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

  Future<void> start({int port = 8080, String nickname = 'MDJ'}) async {
    if (_server != null) throw StateError('Le serveur est déjà démarré.');
    if (nickname.trim().isEmpty || nickname.trim().length > 24) {
      throw ArgumentError('Le pseudo doit contenir entre 1 et 24 caractères.');
    }
    this.nickname = nickname.trim();
    code = '${100000 + _random.nextInt(900000)}';
    locked = false;
    started = false;
    _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
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
            'service': 'le-loup-local',
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
    void error(String message) =>
        socket.add(jsonEncode({'type': 'error', 'message': message}));
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
          error('Session inconnue. Le salon a peut-être été fermé.');
          return;
        }
        final player = _players[id]!;
        if (player['connected'] == true) {
          error(
            'Cette session est encore connectée. Réessaie dans quelques secondes.',
          );
          return;
        }
        _pending.remove(socket);
        player['connected'] = true;
        _peers[socket] = player;
        _trace('Reconnexion de ${player['nickname']}');
        socket.add(
          jsonEncode({'type': 'room.joined', 'id': id, 'token': data['token']}),
        );
        _publish();
        _sendRole(socket, id);
      } else if (data['type'] == 'room.join' && !_peers.containsKey(socket)) {
        final name = (data['nickname'] as String? ?? '').trim();
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
            _peers.values.any(
              (p) =>
                  (p['nickname'] as String).toLowerCase() == name.toLowerCase(),
            )) {
          error('Ce pseudo est déjà utilisé.');
          return;
        }
        if (_peers.length >= 20) {
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
          'ready': false,
          'connected': true,
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
      } else if (data['type'] == 'player.ready' &&
          _peers.containsKey(socket) &&
          !started &&
          data['ready'] is bool) {
        _peers[socket]!['ready'] = data['ready'];
        _publish();
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
    _tokens.removeWhere((_, value) => value == id);
    final sockets = _peers.keys.where((s) => _peers[s]!['id'] == id).toList();
    for (final socket in sockets) {
      _peers.remove(socket);
      await socket.close(4001, 'Vous avez été retiré du salon.');
    }
    _publish();
  }

  void _publish() {
    final encoded = jsonEncode(publicSnapshot);
    for (final peer in _peers.keys.toList()) {
      if (peer.readyState == WebSocket.open) peer.add(encoded);
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
    _tokens.clear();
    _roles.clear();
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
