import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:le_loup/audio/classic_audio.dart';
import 'package:le_loup/audio/voice_settings.dart';
import 'package:le_loup/audio/voice_profiles.dart';
import 'package:le_loup/design/game_theme.dart';
import 'classic_audio_test.dart' show FakeAudio, recordedTestProfiles;

void main() {
  testWidgets(
    'Le catalogue réel affiche les dix voix autorisées et leur couverture',
    (tester) async {
      final audio = ClassicAudio(
        backend: FakeAudio(),
        fadeDuration: Duration.zero,
      );
      addTearDown(audio.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: VoiceSettings(audio: audio)),
          ),
        ),
      );
      expect(audio.availableVoices.length, 10);
      expect(
        find.textContaining('autres annonces restent à lire'),
        findsOneWidget,
      );
      expect(find.text('Masculine'), findsOneWidget);
      expect(find.text('Voix OFF'), findsOneWidget);
    },
  );
  testWidgets(
    'Aucune nouvelle voix validée disponible : narration du MDJ en direct',
    (tester) async {
      final audio = ClassicAudio(
        backend: FakeAudio(),
        profiles: voiceProfiles.where((p) => !p.isApproved).toList(),
        fadeDuration: Duration.zero,
      );
      addTearDown(audio.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: VoiceSettings(audio: audio)),
        ),
      );
      expect(find.text('Narration'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.text('Écouter cette voix'), findsNothing);
    },
  );
  for (final size in [const Size(320, 568), const Size(900, 450)]) {
    testWidgets('Sélection et écoute des voix à $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final backend = FakeAudio();
      final audio = ClassicAudio(
        backend: backend,
        profiles: recordedTestProfiles,
        fadeDuration: Duration.zero,
      );
      addTearDown(audio.dispose);
      audio.welcome();
      await audio.settled;
      await tester.pumpWidget(
        MaterialApp(
          theme: GameTheme.classic,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: VoiceSettings(audio: audio),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('edition-Classique')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Horreur').last);
      await tester.pumpAndSettle();
      expect(audio.voiceProfile.id, 'old_wizard');
      await tester.tap(find.byKey(const ValueKey('voice-old_wizard')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fantôme').last);
      await tester.pumpAndSettle();
      expect(audio.voiceProfile.id, 'ghost');
      await tester.ensureVisible(find.text('Écouter cette voix'));
      await tester.tap(find.text('Écouter cette voix'));
      await tester.pump();
      await audio.settled;
      expect(backend.calls.last, 'neural/ghost/preview.wav');
      expect(tester.takeException(), isNull);
    });
  }
}
