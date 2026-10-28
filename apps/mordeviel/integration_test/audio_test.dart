import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mordeviel/audio/classic_audio.dart';
import 'package:mordeviel/audio/voice_profiles.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Les sons embarqués se décodent sur le lecteur natif', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('Vérification audio'))),
    );
    final player = AudioPlayer();
    try {
      await player.setVolume(0);
      for (final asset in [
        for (final profile in voiceProfiles.where((p) => p.isApproved))
          for (final cue in [...ClassicAudio.voiceAssets, 'preview.wav'])
            if (profile.supports(cue)) profile.assetFor(cue),

        'wolf_howl.mp3',
        'rain_loop.wav',
        'thunder.wav',
        'claw_1.wav',
        'claw_2.wav',
        'moonlit_village.wav',
      ]) {
        await player.setSource(AssetSource('audio/classic/$asset'));
        final duration = await player.getDuration();
        expect(
          duration?.inMilliseconds,
          greaterThan(asset.startsWith('claw_') ? 500 : 1000),
          reason: asset,
        );
      }
      await player.setReleaseMode(ReleaseMode.loop);
      await player.resume();
      expect(player.state, PlayerState.playing);
      await player.pause();
      expect(player.state, PlayerState.paused);
      await player.stop();
      expect(player.state, PlayerState.stopped);
    } finally {
      await player.dispose();
    }
  });
}
