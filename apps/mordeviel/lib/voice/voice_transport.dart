import 'package:flutter/foundation.dart';
// LiveKit 2.13 exposes audio-focus sharing through its experimental session API.
// This explicit policy is required to mix WebRTC with the game's narrator.
// ignore_for_file: experimental_member_use
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
    // Share output with the game's narrator; never request exclusive focus.
    await lk.AudioManager.instance.setAudioSessionOptions(
      const lk.AudioSessionOptions.communication(
        apple: lk.AppleAudioSessionConfiguration(
          category: lk.AppleAudioCategory.playAndRecord,
          mode: lk.AppleAudioMode.voiceChat,
          categoryOptions: {
            lk.AppleAudioCategoryOption.mixWithOthers,
            lk.AppleAudioCategoryOption.defaultToSpeaker,
            lk.AppleAudioCategoryOption.allowBluetooth,
          },
        ),
        android: lk.AndroidAudioSessionConfiguration(
          audioMode: lk.AndroidAudioMode.inCommunication,
          manageAudioFocus: false,
          streamType: lk.AndroidAudioStreamType.music,
          usageType: lk.AndroidAudioAttributesUsageType.media,
          contentType: lk.AndroidAudioAttributesContentType.speech,
        ),
      ),
    );
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
      await room.connect(url, token).timeout(const Duration(seconds: 12));
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
    if (stillAllowed() && identical(room, _room)) {
      // A synchronous push-to-talk cut may precede the SDK's mute operation.
      if (track != null) track.mediaStreamTrack.enabled = true;
    } else {
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
    try {
      await track?.stop().timeout(const Duration(seconds: 3));
    } catch (_) {}
    if (room != null) {
      try {
        await room.disconnect().timeout(const Duration(seconds: 3));
      } finally {
        await room.dispose().timeout(const Duration(seconds: 3));
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
