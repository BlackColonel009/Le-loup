import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import '../audio/classic_audio.dart';

/// Original short UI chimes, independent of the narrator's audio channel.
class ChallengeSounds {
  static AudioPlayer? _player;
  static DateTime? _last;
  static void play({bool completed = false}) {
    final settings = ClassicAudio.instance;
    if (settings.muted || settings.effectLevel == 0) return;
    final now = DateTime.now();
    if (_last != null && now.difference(_last!).inMilliseconds < 850) return;
    _last = now;
    unawaited(
      (_player ??= AudioPlayer())
          .play(
            AssetSource(
              'audio/classic/challenge_${completed ? 'unlock' : 'progress'}.wav',
            ),
            volume: settings.effectLevel * .42,
          )
          .catchError((Object _) {}),
    );
  }

  static void stop() {
    unawaited(
      _player?.stop().catchError((Object _) {}) ?? Future<void>.value(),
    );
  }
}
