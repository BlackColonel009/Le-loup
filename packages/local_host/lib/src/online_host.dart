import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'game_host.dart';

/// Credentials stay in memory and never appear in room snapshots or URLs.
class OnlineHost implements GameHost {
  OnlineHost(String server) : base = onlineServerUri(server);
  final Uri base;
  final _updates = StreamController<Map<String, dynamic>>.broadcast();
  Map<String, dynamic> _room = {};
  WebSocket? _socket;
  StreamSubscription? _subscription;
  String? _token;
  String? _code;
  bool _disposed = false;
  bool get connected => _socket?.readyState == WebSocket.open;
  int _sequence = 0;
  final _pending = <int, Completer<void>>{};

  @override
  Stream<Map<String, dynamic>> get updates => _updates.stream;
  @override
  Map<String, dynamic> get snapshot => Map.of(_room);
  @override
  Map<String, int> get deck =>
      Map<String, int>.from(_room['deck'] as Map? ?? {});

  void _publish({String? error}) {
    if (_disposed || _room.isEmpty) return;
    _updates.add({
      ..._room,
      'online_connected': connected,
      if (error != null) 'online_error': error,
    });
  }

  @override
  Future<void> start({
    int port = 8080,
    String nickname = 'MDJ',
    String? bindAddress,
  }) async {
    final http = HttpClient()..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await http
          .postUrl(base.resolve('rooms'))
          .timeout(const Duration(seconds: 12));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode({'nickname': nickname.trim()}));
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final text = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 201) {
        throw StateError('Création du salon refusée (${response.statusCode}).');
      }
      final room = jsonDecode(text) as Map<String, dynamic>;
      _code = room['code'] as String;
      _token = room['host_token'] as String;
    } finally {
      http.close(force: true);
    }
    await reconnect();
  }

  Future<void> reconnect() async {
    if (_disposed || _token == null || _code == null)
      throw StateError('Aucune session MDJ à reprendre.');
    await _subscription?.cancel();
    await _socket?.close();
    final ready = Completer<void>();
    final uri = onlineSocketUri(base, _code!, host: true);
    final socket = await WebSocket.connect(
      uri.toString(),
    ).timeout(const Duration(seconds: 12));
    _socket = socket;
    void lost() {
      if (_disposed || !identical(_socket, socket)) return;
      _socket = null;
      for (final entry in _pending.values) {
        if (!entry.isCompleted)
          entry.completeError(StateError('Connexion MDJ interrompue.'));
      }
      _pending.clear();
      if (!ready.isCompleted)
        ready.completeError(StateError('Connexion MDJ refusée.'));
      _publish(
        error:
            'Connexion MDJ interrompue. Reconnecte-toi pour reprendre le salon.',
      );
    }

    _subscription = socket.listen(
      (raw) {
        try {
          final event = jsonDecode(raw as String) as Map<String, dynamic>;
          if (event['type'] == 'host.snapshot') {
            _room = Map<String, dynamic>.from(event['room'] as Map);
            _publish();
            if (!ready.isCompleted) ready.complete();
          } else if (event['type'] == 'command.ok') {
            _pending.remove(event['request_id'])?.complete();
          } else if (event['type'] == 'error') {
            final error = StateError(
              event['message'] as String? ?? 'Commande refusée.',
            );
            final pending = _pending.remove(event['request_id']);
            if (pending != null) {
              pending.completeError(error);
            } else {
              _publish(error: error.message);
            }
          }
        } catch (_) {
          _publish(error: 'Réponse du serveur illisible.');
        }
      },
      onDone: lost,
      onError: (Object _) => lost(),
    );
    socket.add(jsonEncode({'token': _token}));
    try {
      await ready.future.timeout(const Duration(seconds: 12));
    } catch (_) {
      await _subscription?.cancel();
      await socket.close();
      _socket = null;
      rethrow;
    }
  }

  Future<void> command(
    String action, [
    Map<String, dynamic> values = const {},
  ]) async {
    if (!connected || _disposed)
      throw StateError('Reconnecte le MDJ avant de continuer.');
    final id = ++_sequence;
    final done = Completer<void>();
    _pending[id] = done;
    try {
      _socket!.add(jsonEncode({...values, 'action': action, 'request_id': id}));
      await done.future.timeout(const Duration(seconds: 15));
    } finally {
      _pending.remove(id);
    }
  }

  void _send(String action, [Map<String, dynamic> values = const {}]) {
    if (!connected) {
      _publish(error: 'Reconnecte le MDJ avant de continuer.');
      return;
    }
    unawaited(
      command(action, values).catchError((Object error) {
        _publish(
          error: error is StateError
              ? error.message
              : 'Le serveur ne répond pas.',
        );
      }),
    );
  }

  @override
  Future<List<String>> addresses() async => [base.toString()];
  @override
  void configure(
    Map<String, int> deck, {
    required bool campOnly,
    bool? revealOnDeath,
    String? pack,
    List<String>? sentences,
  }) => _send('configure', {
    'deck': deck,
    'camp_only': campOnly,
    if (revealOnDeath != null) 'reveal_on_death': revealOnDeath,
    if (pack != null) 'pack': pack,
    if (sentences != null) 'sentences': sentences,
  });
  @override
  void setLocked(bool value) => _send('lock', {'locked': value});
  @override
  void setNarration({required String profile, required bool automatic}) =>
      _send('narration.configure', {
        'profile': profile,
        'automatic': automatic,
      });
  @override
  Future<void> kick(String id) => command('kick', {'player_id': id});
  @override
  void startGame() => _send('start');
  @override
  void startNight({int seconds = 120}) =>
      _send('night.start', {'seconds': seconds});
  @override
  void callNight(String action) => _send('night.call', {'call': action});
  @override
  void advanceNight() => _send('night.advance');
  @override
  void finishNight() => _send('night.finish');
  @override
  void pauseNight() => _send('pause');
  @override
  void resumeNight() => _send('resume');
  @override
  void startVote({int seconds = 120}) =>
      _send('vote.start', {'seconds': seconds});
  @override
  void setDayChat(bool value) => _send('day.chat', {'open': value});
  @override
  void spinSentence() => _send('sentence.spin');
  @override
  void continueAfterSentence() => _send('sentence.continue');
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    if (connected) {
      _socket!.add(jsonEncode({'action': 'room.close'}));
      try {
        await _socket!.done.timeout(const Duration(seconds: 3));
      } catch (_) {
        /* A dropped connection leaves the remote room until expiry. */
      }
    }
    _disposed = true;
    await _subscription?.cancel();
    await _socket?.close();
    _socket = null;
    _token = null;
    for (final pending in _pending.values) {
      if (!pending.isCompleted)
        pending.completeError(StateError('Session fermée.'));
    }
    _pending.clear();
    await _updates.close();
  }
}

Uri onlineServerUri(String value) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      !['http', 'https'].contains(uri.scheme) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw const FormatException(
      'Indique une adresse de serveur http:// ou https:// valide.',
    );
  }
  return uri.replace(path: uri.path.endsWith('/') ? uri.path : '${uri.path}/');
}

Uri onlineSocketUri(Uri base, String code, {bool host = false}) {
  if (!RegExp(r'^\d{6}$').hasMatch(code))
    throw const FormatException('Code à six chiffres requis.');
  return base
      .resolve('rooms/$code/${host ? 'host' : 'ws'}')
      .replace(scheme: base.scheme == 'https' ? 'wss' : 'ws');
}
