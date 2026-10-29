import 'dart:async';
import 'dart:convert';
import 'dart:io';

class LobbyClient {
  WebSocket? _socket;
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _events.stream;
  String? id;
  String? _token;
  String? _address;
  String? _code;
  String? _nickname;
  String _appearance = 'male';
  String? _accountToken;
  bool _closed = false;
  bool _inGame = false;
  bool _background = false;
  bool _manualDisconnect = false;
  bool _reconnecting = false;
  Timer? _retry;
  int _retryCount = 0;

  Future<void> reconnect() async {
    if (_closed || _reconnecting) return;
    if (_address == null || (_inGame && _token == null))
      throw StateError('Aucune session à reprendre.');
    _retry?.cancel();
    _manualDisconnect = false;
    _reconnecting = true;
    try {
      await connect(
        _address!,
        _code!,
        _nickname!,
        appearance: _appearance,
        communityToken: _accountToken,
      );
    } finally {
      _reconnecting = false;
    }
  }

  void _retryConnection() {
    if (_closed || _manualDisconnect || _retryCount >= 12) return;
    _retry?.cancel();
    final delay = Duration(seconds: (++_retryCount * 2).clamp(2, 10));
    _retry = Timer(delay, () async {
      try {
        await reconnect();
      } catch (_) {
        _retryConnection();
      }
    });
  }

  Future<void> connect(
    String address,
    String code,
    String nickname, {
    String appearance = 'male',
    String? communityToken,
  }) async {
    _accountToken = communityToken;
    _appearance = appearance;
    final previous = _socket;
    _socket = null;
    await previous?.close();
    _address = address;
    _code = code;
    _nickname = nickname;
    final input = address.trim();
    final remote = input.startsWith('ws://') || input.startsWith('wss://');
    final uri = Uri.tryParse(remote ? input : 'ws://$input/ws');
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        !['ws', 'wss'].contains(uri.scheme) ||
        !(uri.path == '/ws' || uri.path == '/rooms/${code.trim()}/ws') ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException(
        'Adresse attendue : IP:port ou URL ws(s) du salon.',
      );
    }
    var timedOut = false;
    final connection = WebSocket.connect(uri.toString());
    connection.then((socket) {
      if (timedOut || _closed) socket.close();
    }, onError: (Object _) {});
    final socket = await connection.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        timedOut = true;
        throw TimeoutException('Connexion expirée.');
      },
    );
    if (_closed) {
      await socket.close();
      return;
    }
    _socket = socket;
    // Le serveur pilote les pings. Deux minuteurs courts ne sont pas nécessaires.
    var disconnectReported = false;
    void reportDisconnect({Object? error}) {
      if (_closed || !identical(_socket, socket) || disconnectReported) return;
      disconnectReported = true;
      final reason = socket.closeReason;
      final status = socket.closeCode;
      final terminal =
          status == 1008 ||
          status == 4001 ||
          (reason?.contains('fermé') ?? false);
      final message = reason != null && reason.isNotEmpty
          ? reason
          : error != null
          ? 'Connexion interrompue : $error'
          : status == 1001
          ? 'Connexion interrompue : le serveur ne répond plus ou a fermé la connexion.'
          : 'Connexion interrompue${status == null ? ' sans motif reçu du serveur' : ' (code $status)'}.';
      _events.add({
        'type': 'disconnected',
        'message': message,
        'close_code': status,
        'terminal': terminal,
        if (error != null) 'detail': error.toString(),
      });
      if (!terminal) {
        _retryConnection();
      }
    }

    socket.listen(
      (raw) {
        if (_closed || !identical(_socket, socket)) return;
        try {
          final data = jsonDecode(raw as String) as Map<String, dynamic>;
          if (data['type'] == 'error' && data['code'] == 'resume_busy') {
            // The previous transport may still be completing its close handshake.
            socket.close(1000, 'Reprise différée');
          }
          if (data['type'] == 'error' && data['code'] == 'resume_missing') {
            socket.close(
              1008,
              'La place réservée a expiré. Rejoins de nouveau le salon.',
            );
          }
          if (data['type'] == 'room.joined') {
            id = data['id'] as String;
            _token = data['token'] as String?;
            _retry?.cancel();
            _retryCount = 0;
            setBackground(_background);
          }
          if (data['type'] == 'room.snapshot') {
            _inGame = data['phase'] != 'lobby';
          }
          _events.add(data);
        } catch (_) {
          _events.add({
            'type': 'error',
            'message': 'Réponse du serveur invalide.',
          });
        }
      },
      onDone: () {
        reportDisconnect();
      },
      onError: (Object error) {
        reportDisconnect(error: error);
      },
    );
    socket.add(
      jsonEncode({
        'version': 1,
        'type': _token == null ? 'room.join' : 'room.resume',
        if (_token != null) 'token': _token,
        'code': code.trim(),
        'nickname': nickname.trim(),
        'appearance': _appearance,
        if (remote && _accountToken != null) 'account_token': _accountToken,
      }),
    );
  }

  void setReady(bool ready) => _socket?.add(
    jsonEncode({'version': 1, 'type': 'player.ready', 'ready': ready}),
  );

  void setBackground(bool background) {
    _background = background;
    final socket = _socket;
    if (id != null && socket?.readyState == WebSocket.open) {
      socket!.add(
        jsonEncode({
          'version': 1,
          'type': 'player.background',
          'background': background,
        }),
      );
    }
  }

  void gameAction(
    String action,
    int revision, {
    String? target,
    bool? save,
    String? kill,
    String? text,
    List<String>? targets,
  }) => _socket?.add(
    jsonEncode({
      'version': 1,
      'type': 'game.action',
      'action': action,
      'phase_revision': revision,
      if (target != null) 'target': target,
      if (save != null) 'save': save,
      'kill': kill,
      if (text != null) 'text': text,
      if (targets != null) 'targets': targets,
    }),
  );

  /// Ferme le transport sans effacer la session, pour une reprise ultérieure.
  Future<void> disconnect() async {
    _manualDisconnect = true;
    _retry?.cancel();
    await _socket?.close();
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    _retry?.cancel();
    final socket = _socket;
    _socket = null;
    if (socket?.readyState == WebSocket.open && id != null) {
      try {
        socket!.add(jsonEncode({'version': 1, 'type': 'room.leave'}));
      } catch (_) {
        // A lost transport will be removed after the server grace period.
      }
    }
    await socket?.close();
    await _events.close();
  }
}
