import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mordeviel/voice/game_voice.dart';
import 'package:mordeviel/voice/voice_transport.dart';
import 'package:mordeviel/audio/classic_audio.dart';

class FakeVoiceTransport extends VoiceTransport {
  bool online = false, mic = false;
  Completer<void>? capture;
  int connections = 0;
  @override
  bool get connected => online;
  @override
  Set<String> get speakers => online && mic ? {'player'} : {};
  @override
  Future<void> connect(String url, String token) async {
    connections++;
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
  test(
    'Une actualisation de phase conserve le transport si le canal est inchangé',
    () async {
      final transport = FakeVoiceTransport();
      var epoch = 'village', calls = 0;
      final voice = GameVoice(
        transport: transport,
        audio: ClassicAudio(),
        loader: (_, _) async {
          calls++;
          return {
            'epoch': epoch,
            'channel': epoch,
            'publish': true,
            'url': 'wss://voice.invalid',
            'token': 'fake',
          };
        },
      );
      addTearDown(voice.dispose);
      contextFor(voice, 'day');
      await voice.join();
      expect(transport.connections, 1);
      contextFor(voice, 'voting');
      expect(transport.connected, isTrue);
      await Future<void>.delayed(Duration.zero);
      await voice.refresh();
      expect(transport.connections, 1);
      epoch = 'wolves';
      contextFor(voice, 'wolves');
      await Future<void>.delayed(Duration.zero);
      await voice.refresh();
      expect(transport.connections, 2);
      expect(calls, greaterThanOrEqualTo(3));
      await voice.leave();
    },
  );
  test(
    'Un appel de rôle arrivé pendant une requête vocale est traité sans attendre le poll',
    () async {
      final pending = Completer<Map<String, dynamic>>();
      var calls = 0;
      final transport = FakeVoiceTransport();
      final voice = GameVoice(
        transport: transport,
        audio: ClassicAudio(),
        loader: (_, _) async {
          if (++calls == 1) return pending.future;
          return {
            'epoch': 'wolves',
            'channel': 'wolves',
            'publish': true,
            'url': 'wss://voice.invalid',
            'token': 'new',
          };
        },
      );
      addTearDown(voice.dispose);
      contextFor(voice, 'day');
      final joining = voice.join();
      contextFor(voice, 'wolves');
      pending.complete({
        'epoch': 'day',
        'channel': 'village',
        'publish': true,
        'url': 'wss://voice.invalid',
        'token': 'old',
      });
      await joining;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(calls, 2);
      expect(voice.channel, 'wolves');
      expect(transport.connected, isTrue);
      await voice.leave();
    },
  );
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
