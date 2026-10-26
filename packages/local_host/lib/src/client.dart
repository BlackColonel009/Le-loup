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
  bool _closed = false;
  bool _inGame = false;

  Future<void> reconnect() async {
    if (_address == null || (_inGame && _token == null))
      throw StateError('Aucune session à reprendre.');
    if (!_inGame) {
      _token = null;
      id = null;
    }
    await connect(_address!, _code!, _nickname!);
  }

  Future<void> connect(String address, String code, String nickname) async {
    final previous = _socket;
    _socket = null;
    await previous?.close();
    _address = address;
    _code = code;
    _nickname = nickname;
    final uri = Uri.tryParse('ws://${address.trim()}/ws');
    if (uri == null ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.path != '/ws' ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('Adresse attendue : 192.168.1.10:8080');
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
        if (error != null) 'detail': error.toString(),
      });
    }

    socket.listen(
      (raw) {
        if (_closed || !identical(_socket, socket)) return;
        try {
          final data = jsonDecode(raw as String) as Map<String, dynamic>;
          if (data['type'] == 'room.joined') {
            id = data['id'] as String;
            _token = data['token'] as String?;
          }
          if (data['type'] == 'room.snapshot')
            _inGame = data['phase'] == 'role_reveal';
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
      }),
    );
  }

  void setReady(bool ready) => _socket?.add(
    jsonEncode({'version': 1, 'type': 'player.ready', 'ready': ready}),
  );

  /// Ferme le transport sans effacer la session, pour une reprise ultérieure.
  Future<void> disconnect() async {
    await _socket?.close();
  }

  Future<void> dispose() async {
    _closed = true;
    await _socket?.close();
    await _events.close();
  }
}
