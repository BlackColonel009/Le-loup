import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/audio/classic_audio.dart';
import 'package:mordeviel/voice/game_voice.dart';
import 'package:mordeviel/voice/voice_bar.dart';
import 'package:mordeviel/village/village_chat.dart';
import 'package:mordeviel/village/village_navigation.dart';
import 'game_voice_test.dart' show FakeVoiceTransport, contextFor;

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('CAPTURE_IMMERSION')) return;
    for (final entry in {
      'VillageSans': 'assets/fonts/SourceSans3[wght].ttf',
      'MaterialIcons':
          'C:/bibliotheque/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final bytes = await File(entry.value).readAsBytes();
      await (FontLoader(
        entry.key,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });
  for (final size in [const Size(360, 740), const Size(900, 420)]) {
    testWidgets('Vocal et conseil restent lisibles à $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final transport = FakeVoiceTransport();
      final voice = GameVoice(
        transport: transport,
        audio: ClassicAudio(),
        loader: (_, _) async => {
          'epoch': 'one',
          'channel': 'village',
          'publish': true,
          'url': 'wss://voice.invalid',
          'token': 'fixture',
        },
      );
      addTearDown(voice.dispose);
      contextFor(voice, 'day');
      await voice.join();
      await voice.microphoneSettled;
      final boundary = GlobalKey();
      final room = <String, dynamic>{
        'phase': 'day',
        'players': <Map>[],
        'game': {
          'phase_revision': 1,
          'chat_open': true,
          'day_messages': <Map>[],
        },
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            textTheme: ThemeData.dark().textTheme.apply(
              fontFamily: 'VillageSans',
            ),
          ),
          home: RepaintBoundary(
            key: boundary,
            child: Scaffold(
              body: VillageNavigation(
                destination: VillageDestination.chat,
                phase: 'day',
                isHost: false,
                code: '123456',
                onSelect: (_) {},
                onCodex: () {},
                village: const SizedBox(),
                actions: const SizedBox(),
                preparation: const SizedBox(),
                chat: VillageChat(
                  fullPage: true,
                  room: room,
                  connected: true,
                  isHost: false,
                  privateState: const {'alive': true},
                  onSend: (_, _, _) {},
                ),
                voiceControl: VoiceBar(voice: voice),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final mic = find.byIcon(Icons.mic_off);
      final finger = await tester.startGesture(tester.getCenter(mic));
      await tester.pump();
      await voice.microphoneSettled;
      await tester.pump();
      expect(transport.mic, true);
      await finger.up();
      await voice.microphoneSettled;
      await tester.pump();
      expect(transport.mic, false);
      if (const bool.fromEnvironment('CAPTURE_IMMERSION')) {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '../../.tmp/voice-ui-${size.width.toInt()}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.showKeyboard(find.byType(TextField));
      tester.view.viewInsets = FakeViewPadding(bottom: size.height * .45);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.mic_off), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await voice.leave();
    });
  }
}
