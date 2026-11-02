import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

abstract class VoiceTransport extends ChangeNotifier {
  bool get connected;
  Set<String> get speakers;
  Future<void> connect(String url, String token);
  Future<void> disconnect();
  Future<void> microphone(bool enabled, bool Function() stillAllowed);
  void silence();
}

class LiveKitVoiceTransport extends VoiceTransport {
  lk.Room? _room;
  lk.LocalAudioTrack? _track;
  bool _disposed = false;
  @override
  bool get connected => _room?.connectionState == lk.ConnectionState.connected;
  @override
  Set<String> get speakers =>
      _room?.activeSpeakers.map((p) => p.identity).toSet() ?? {};
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  Future<void> connect(String url, String token) async {
    if (_disposed) return;
    await disconnect();
    final room = lk.Room(
      roomOptions: const lk.RoomOptions(
        defaultAudioPublishOptions: lk.AudioPublishOptions(
          encoding: lk.AudioEncoding.presetSpeech,
          dtx: true,
        ),
      ),
    );
    _room = room;
    room.addListener(_changed);
    try {
      await room.connect(url, token);
    } catch (_) {
      await disconnect();
      rethrow;
    }
    if (_disposed || !identical(room, _room)) {
      await room.disconnect();
      await room.dispose();
      return;
    }
    try {
      await lk.AudioManager.instance.setSpeakerOutputPreferred(true);
    } catch (_) {
      // Platforms without manual routing retain their system audio output.
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void silence() {
    // Cut the local track before awaiting any network or permission operation.
    final track = _track;
    if (track != null && !track.muted) track.mediaStreamTrack.enabled = false;
  }

  @override
  Future<void> microphone(bool enabled, bool Function() stillAllowed) async {
    final room = _room;
    if (!enabled) {
      silence();
      await _track?.mute();
      return;
    }
    if (room == null || !connected || !stillAllowed()) return;
    if (_track == null) {
      // Capture can show a native permission dialog. Do not publish anything
      // until the hold is still valid after that dialog closes.
      final track = await lk.LocalAudioTrack.create(
        const lk.AudioCaptureOptions(),
      );
      await track.mute(stopOnMute: false);
      if (!stillAllowed() || !identical(room, _room)) {
        await track.dispose();
        return;
      }
      _track = track;
      try {
        await room.localParticipant!.publishAudioTrack(track);
      } catch (_) {
        if (identical(_track, track)) _track = null;
        await track.dispose();
        rethrow;
      }
      if (!identical(room, _room)) {
        await track.dispose();
        return;
      }
    }
    if (!stillAllowed() || !identical(room, _room)) {
      silence();
      await _track?.mute();
      return;
    }
    final track = _track;
    await track?.unmute();
    if (!stillAllowed()) {
      silence();
      await track?.mute();
    }
  }

  @override
  Future<void> disconnect() async {
    silence();
    final room = _room;
    final track = _track;
    _room = null;
    _track = null;
    room?.removeListener(_changed);
    await track?.stop();
    if (room != null) {
      try {
        await room.disconnect();
      } finally {
        await room.dispose();
      }
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
