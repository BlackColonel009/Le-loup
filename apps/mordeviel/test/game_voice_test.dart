import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/voice/game_voice.dart';
import 'package:mordeviel/voice/voice_transport.dart';
import 'package:mordeviel/audio/classic_audio.dart';

class FakeVoiceTransport extends VoiceTransport {
  bool online = false, mic = false;
  Completer<void>? capture;
  @override
  bool get connected => online;
  @override
  Set<String> get speakers => online && mic ? {'player'} : {};
  @override
  Future<void> connect(String url, String token) async {
    online = true;
    notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    online = false;
    mic = false;
    notifyListeners();
  }

  @override
  void silence() {
    mic = false;
  }

  @override
  Future<void> microphone(bool enabled, bool Function() allowed) async {
    if (enabled) await capture?.future;
    mic = enabled && allowed();
  }
}

void contextFor(GameVoice voice, String phase) => voice.updateContext(
  code: '123456',
  credential: 'private-test-session',
  contextKey: phase,
  enabled: true,
  gameConnected: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Maintien, relâchement, verrouillage et changement de phase', () async {
    final transport = FakeVoiceTransport();
    var epoch = 'day';
    var publish = true;
    final audio = ClassicAudio();
    final voice = GameVoice(
      transport: transport,
      audio: audio,
      loader: (_, _) async => {
        'epoch': epoch,
        'channel': 'village',
        'publish': publish,
        'url': 'wss://voice.invalid',
        'token': 'fake-media-token',
      },
    );
    addTearDown(voice.dispose);
    contextFor(voice, 'day');
    await voice.join();
    await voice.microphoneSettled;
    expect(transport.mic, false);
    voice.hold(true);
    await voice.microphoneSettled;
    expect(transport.mic, true);
    voice.hold(false);
    expect(transport.mic, false);
    await voice.microphoneSettled;
    voice.toggleLock();
    await voice.microphoneSettled;
    expect(transport.mic, true);
    epoch = 'night';
    contextFor(voice, 'wolves');
    expect(transport.mic, false);
    expect(voice.locked, false);
    await Future<void>.delayed(Duration.zero);
    await voice.microphoneSettled;
    publish = false;
    await voice.refresh();
    expect(voice.canSpeak, false);
    voice.hold(true);
    await voice.microphoneSettled;
    expect(transport.mic, false);
    await voice.leave();
  });
  test(
    'Relâcher pendant l’autorisation du micro ne publie pas ensuite',
    () async {
      final transport = FakeVoiceTransport()..capture = Completer<void>();
      final voice = GameVoice(
        transport: transport,
        audio: ClassicAudio(),
        loader: (_, _) async => {
          'epoch': 'one',
          'channel': 'village',
          'publish': true,
          'url': 'wss://voice.invalid',
          'token': 'fake',
        },
      );
      addTearDown(voice.dispose);
      contextFor(voice, 'day');
      await voice.join();
      await voice.microphoneSettled;
      voice.hold(true);
      await Future<void>.delayed(Duration.zero);
      voice.hold(false);
      transport.capture!.complete();
      await voice.microphoneSettled;
      expect(transport.mic, false);
      expect(voice.transmitting, false);
      voice.toggleLock();
      await voice.microphoneSettled;
      expect(transport.mic, true);
      voice.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(transport.mic, false);
      expect(voice.locked, false);
      await voice.leave();
    },
  );
  test('Une panne vocale ne propage pas d’exception au jeu', () async {
    final voice = GameVoice(
      transport: FakeVoiceTransport(),
      audio: ClassicAudio(),
      loader: (_, _) async => throw StateError('Vocal indisponible.'),
    );
    addTearDown(voice.dispose);
    contextFor(voice, 'day');
    await voice.join();
    expect(voice.canSpeak, false);
    expect(voice.error, 'Vocal indisponible.');
    await voice.leave();
  });
}
