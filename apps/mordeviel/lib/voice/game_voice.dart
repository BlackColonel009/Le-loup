import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/widgets.dart';
import '../audio/classic_audio.dart';
import '../services/server_config.dart';
import 'voice_transport.dart';

typedef VoiceGrantLoader =
    Future<Map<String, dynamic>> Function(String code, String credential);

class VoiceGrantFailure extends StateError {
  VoiceGrantFailure(this.status, String message) : super(message);
  final int status;
}

Future<Map<String, dynamic>> loadVoiceGrant(
  String code,
  String credential,
) async {
  final http = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final base = Uri.parse(apiBaseUrl);
    final request = await http
        .postUrl(base.resolve('/rooms/$code/voice/access'))
        .timeout(const Duration(seconds: 6));
    request.followRedirects = false;
    request.headers.set('Authorization', 'Bearer $credential');
    final response = await request.close().timeout(const Duration(seconds: 6));
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(const Duration(seconds: 6));
    Map<String, dynamic>? data;
    try {
      data = Map<String, dynamic>.from(jsonDecode(body) as Map);
    } catch (_) {}
    if (response.statusCode != 200) {
      throw VoiceGrantFailure(
        response.statusCode,
        data?['detail'] as String? ??
            'Le vocal est indisponible. Le chat écrit reste accessible.',
      );
    }
    if (data == null) {
      throw StateError('Le service vocal a renvoyé une réponse inattendue.');
    }
    return data;
  } finally {
    http.close(force: true);
  }
}

class GameVoice extends ChangeNotifier with WidgetsBindingObserver {
  GameVoice({
    VoiceTransport? transport,
    VoiceGrantLoader? loader,
    ClassicAudio? audio,
    this.pollInterval = const Duration(seconds: 2),
  }) : transport = transport ?? LiveKitVoiceTransport(),
       _loader = loader ?? loadVoiceGrant,
       _audio = audio ?? ClassicAudio.instance {
    WidgetsBinding.instance.addObserver(this);
    this.transport.addListener(_transportChanged);
    _audio.addListener(_audioChanged);
  }
  final VoiceTransport transport;
  final VoiceGrantLoader _loader;
  final ClassicAudio _audio;
  final Duration pollInterval;
  String? _code, _credential, _context, _epoch;
  String? channel, error;
  bool wanted = false, busy = false, locked = false, transmitting = false;
  bool _publish = false, _held = false, _foreground = true, _disposed = false;
  bool _refreshing = false, _refreshQueued = false;
  DateTime? _retryAfter;
  int _failures = 0;
  int _generation = 0;
  Timer? _poll;
  Future<void> _writes = Future.value();
  Future<void> _media = Future.value();
  Future<void> get microphoneSettled => _writes;
  bool get connected => transport.connected;
  bool get canSpeak =>
      wanted &&
      connected &&
      _publish &&
      _foreground &&
      !_audio.narrationPlaying;
  Set<String> get speakers => connected ? transport.speakers : {};

  void updateContext({
    required String? code,
    required String? credential,
    required String contextKey,
    required bool enabled,
    required bool gameConnected,
  }) {
    final next = enabled && gameConnected ? '$code:$contextKey' : null;
    final changedCredential = credential != _credential || code != _code;
    _code = code;
    _credential = credential;
    if (next == _context && !changedCredential) return;
    _context = next;
    _generation++;
    _cut();
    _publish = false;
    if (changedCredential || next == null) {
      _retryAfter = null;
      _failures = 0;
      _epoch = null;
      unawaited(_disconnect());
    }
    if (wanted) unawaited(refresh());
  }

  Future<void> join() async {
    _retryAfter = null;
    wanted = true;
    error = null;
    _poll ??= Timer.periodic(pollInterval, (_) => unawaited(refresh()));
    await refresh();
  }

  Future<void> leave() async {
    wanted = false;
    _generation++;
    _poll?.cancel();
    _poll = null;
    _cut();
    _publish = false;
    channel = null;
    _epoch = null;
    await _disconnect();
  }

  Future<void> _disconnect() async {
    await _serializeMedia(() async {
      try {
        await transport.disconnect();
      } catch (_) {}
    });
    if (!_disposed) notifyListeners();
  }

  Future<void> _serializeMedia(Future<void> Function() action) {
    final next = _media.catchError((Object _) {}).then((_) => action());
    _media = next.catchError((Object _) {});
    return next;
  }

  Future<void> refresh() async {
    if (_retryAfter != null && DateTime.now().isBefore(_retryAfter!)) return;
    if (_disposed ||
        !wanted ||
        !_foreground ||
        _context == null ||
        _code == null ||
        _credential == null) {
      return;
    }
    if (_refreshing) {
      _refreshQueued = true;
      return;
    }
    _refreshing = true;
    busy = !connected;
    if (busy) notifyListeners();
    final generation = _generation;
    try {
      final grant = await _loader(
        _code!,
        _credential!,
      ).timeout(const Duration(seconds: 8));
      if (_disposed || generation != _generation || !wanted || !_foreground) {
        return;
      }
      final epoch = grant['epoch'] as String?;
      final nextChannel = grant['channel'] as String?;
      final publish = grant['publish'] == true;
      if (epoch != _epoch || !publish) _cut();
      _publish = publish;
      channel = nextChannel;
      if (nextChannel == null) {
        await _disconnect();
        _epoch = null;
        return;
      }
      if (epoch != _epoch || !connected) {
        _cut();
        busy = true;
        notifyListeners();
        await _serializeMedia(() async {
          if (_disposed ||
              generation != _generation ||
              !wanted ||
              !_foreground) {
            return;
          }
          await transport.disconnect();
          if (_disposed ||
              generation != _generation ||
              !wanted ||
              !_foreground) {
            return;
          }
          await transport.connect(
            grant['url'] as String,
            grant['token'] as String,
          );
          if (_disposed ||
              generation != _generation ||
              !wanted ||
              !_foreground) {
            await transport.disconnect();
            return;
          }
          _epoch = epoch;
        });
      }
      error = null;
      _failures = 0;
      _retryAfter = null;
    } catch (failure) {
      if (!_disposed && generation == _generation) {
        _failures = (_failures + 1).clamp(1, 4);
        _retryAfter = DateTime.now().add(
          Duration(seconds: 2 * (1 << _failures)),
        );
        _cut();
        _publish = false;
        error = failure is StateError
            ? failure.message.toString()
            : 'Connexion vocale impossible. Vérifie Internet et les autorisations ; la partie continue par écrit.';
        if (failure is VoiceGrantFailure &&
            [401, 403, 404].contains(failure.status)) {
          await _disconnect();
        }
      }
    } finally {
      busy = false;
      _refreshing = false;
      if (!_disposed) notifyListeners();
      if (_refreshQueued) {
        _refreshQueued = false;
        if (!_disposed) unawaited(refresh());
      }
    }
  }

  void hold(bool value) {
    _held = value && canSpeak;
    if (!value && !locked) transport.silence();
    _applyMicrophone();
  }

  void toggleLock() {
    if (!canSpeak) return;
    locked = !locked;
    if (!locked) {
      _held = false;
      transport.silence();
    }
    _applyMicrophone();
  }

  bool get _intent => !_disposed && canSpeak && (_held || locked);
  void pauseMicrophone() => _cut();
  void _cut() {
    _held = false;
    locked = false;
    transmitting = false;
    transport.silence();
    _applyMicrophone();
  }

  void _applyMicrophone() {
    if (_disposed) return;
    _writes = _writes.then((_) async {
      if (_disposed) return;
      try {
        await transport.microphone(_intent, () => _intent);
        transmitting = _intent;
      } catch (_) {
        transport.silence();
        _held = false;
        locked = false;
        transmitting = false;
        error =
            'Microphone indisponible ou refusé. Autorise le micro dans les réglages de Mordeviel puis réessaie.';
      }
      if (!_disposed) notifyListeners();
    });
  }

  void _audioChanged() {
    if (_audio.narrationPlaying) _cut();
  }

  void _transportChanged() {
    if (_disposed) return;
    if (!connected) {
      _cut();
    }
    _audio.conversation(speakers.isNotEmpty || transmitting);
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _generation++;
      _cut();
      unawaited(_disconnect());
    } else if (wanted) {
      unawaited(refresh());
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _cut();
    _disposed = true;
    _generation++;
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _audio.removeListener(_audioChanged);
    transport.removeListener(_transportChanged);
    _audio.conversation(false);
    unawaited(
      _disconnect().catchError((Object _) {}).whenComplete(transport.dispose),
    );
    super.dispose();
  }
}
