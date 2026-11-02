import 'package:audioplayers/audioplayers.dart';
import 'classic_audio.dart';
import '../services/immersion_preferences.dart';

/// Generic private UI sound; never identifies a secret role.
class CardFoley {
  static AudioPlayer? _player;
  static void play() {
    final audio = ClassicAudio.instance;
    if (!ImmersionPreferences.instance.cardSounds ||
        audio.muted ||
        audio.scene == AudioScene.silent ||
        audio.effectLevel == 0) {
      return;
    }
    (_player ??= AudioPlayer())
        .play(
          AssetSource('audio/classic/card_flick.wav'),
          volume: audio.effectLevel * .22,
        )
        .catchError((Object _) {});
  }
}
