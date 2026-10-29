import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_host/local_host.dart';
import 'voice_profiles.dart';
import '../village/ending_data.dart';
import '../content/pack_store.dart';
import '../content/pack_messages.dart';

enum AudioScene { welcome, host, silent }

abstract interface class AudioBackend {
  Stream<void> get cueFinished;
  Future<void> music(double volume);
  Future<void> cue(String asset, double volume);
  Future<void> musicVolume(double volume);
  Future<void> cueVolume(double volume);
  Future<void> stopCue();
  Future<void> weather(String? asset, double volume);
  Future<void> thunder(double volume);
  Future<void> stop();
  Future<void> dispose();
}

class AssetAudioBackend implements AudioBackend {
  static bool available(String asset) =>
      !asset.startsWith('neural/') ||
      asset.startsWith('neural/classic_') ||
      asset.endsWith('/preview.wav') ||
      PackStore.instance.pathFor('assets/audio/classic/$asset') != null;
  final _music = AudioPlayer();
  final _cue = AudioPlayer();
  final _rain = AudioPlayer();
  final _thunder = AudioPlayer();
  String? _rainAsset;
  @override
  Stream<void> get cueFinished => _cue.onPlayerComplete;
  @override
  Future<void> music(double volume) async {
    if (_music.state == PlayerState.playing) {
      await _music.setVolume(volume);
      return;
    }
    await _music.setReleaseMode(ReleaseMode.loop);
    await _music.play(
      AssetSource('audio/classic/moonlit_village.wav'),
      volume: volume,
    );
  }

  @override
  Future<void> cue(String asset, double volume) async {
    await _cue.stop();
    final path = PackStore.instance.pathFor('assets/audio/classic/$asset');
    if (!available(asset)) {
      throw MissingPackException(downloadablePackForAsset(asset)!);
    }
    await _cue.play(
      path == null
          ? AssetSource('audio/classic/$asset')
          : DeviceFileSource(path),
      volume: volume,
    );
  }

  @override
  Future<void> musicVolume(double volume) async {
    if (volume > 0 && _music.state != PlayerState.playing) {
      await music(volume);
    } else {
      await _music.setVolume(volume);
    }
  }

  @override
  Future<void> cueVolume(double volume) => _cue.setVolume(volume);
  @override
  Future<void> stopCue() => _cue.stop();
  @override
  Future<void> weather(String? asset, double volume) async {
    if (asset == null || volume == 0) {
      await _rain.stop();
      await _thunder.stop();
      _rainAsset = null;
    } else if (_rainAsset == asset) {
      await _rain.setVolume(volume);
      await _thunder.setVolume((volume * 2).clamp(0, 1));
    } else {
      await _rain.setReleaseMode(ReleaseMode.loop);
      await _rain.play(AssetSource('audio/classic/$asset'), volume: volume);
      _rainAsset = asset;
    }
  }

  @override
  Future<void> thunder(double volume) async {
    await _thunder.stop();
    await _thunder.play(
      AssetSource('audio/classic/thunder.wav'),
      volume: volume,
    );
  }

  @override
  Future<void> stop() async {
    await _cue.stop();
    await _music.stop();
    await _rain.stop();
    await _thunder.stop();
    _rainAsset = null;
  }

  @override
  Future<void> dispose() async {
    await _cue.dispose();
    await _music.dispose();
    await _rain.dispose();
    await _thunder.dispose();
  }
}

/// Une seule régie par appareil. Les instantanés réseau ne rejouent pas un appel.
class ClassicAudio extends ChangeNotifier with WidgetsBindingObserver {
  ClassicAudio({
    AudioBackend? backend,
    List<VoiceProfile>? profiles,
    this.fadeDuration = const Duration(seconds: 3),
  }) : _backend = backend,
       _profiles = List.unmodifiable(profiles ?? voiceProfiles) {
    _voiceProfile = _findVoice(null);
    _completion = backend?.cueFinished.listen((_) => _cueEnded());
  }
  static final instance = ClassicAudio();
  final Duration fadeDuration;
  AudioBackend? _backend;
  final List<VoiceProfile> _profiles;
  List<VoiceProfile> get availableVoices =>
      _profiles.where((p) => p.isApproved).toList(growable: false);
  VoiceProfile _findVoice(String? id) => _profiles.firstWhere(
    (p) => p.id == id && p.isApproved,
    orElse: () => _profiles.firstWhere(
      (p) => p.isApproved,
      orElse: () => disabledVoiceProfile,
    ),
  );
  SharedPreferences? _preferences;
  StreamSubscription<void>? _completion;
  Future<void> _pending = Future.value();
  Timer? _save;
  Timer? _storm;
  VillageWeather _weather = const VillageWeather();
  final _weatherClock = Stopwatch();
  bool _gamePaused = false;
  int? _lastThunder;
  AudioScene scene = AudioScene.silent;
  double musicLevel = .35, voiceLevel = .85, effectLevel = .65;
  bool muted = false;
  bool narrationEnabled = true;
  bool _foreground = true, _howled = false, _ducked = false, _disposed = false;
  bool _cueIsVoice = false;
  bool _opening = false;
  Completer<void>? _welcomeHowl;
  bool _welcomeHowlActive = false;
  Future<void> get welcomeHowlFinished =>
      _welcomeHowl?.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {},
      ) ??
      Future<void>.value();
  int _epoch = 0, _fade = 0, _cueTicket = 0;
  String? _lastCue, _currentVoice, _lastPotionCue;
  int _stories = 0;
  int _deathTicket = 0;
  Completer<void>? _cancelCurrentStory;
  String? error;
  List<String> missingPackIds = const [];
  VoiceProfile _voiceProfile = voiceProfiles.first;
  VoiceProfile? _roomVoice;
  bool roomAutomatic = true;
  bool automaticNarrationPreferred = true;
  VoiceProfile get voiceProfile => _roomVoice ?? _voiceProfile;
  String? _narrationRoom;
  int _narrationRevision = -1;
  int _narrationGeneration = 0;
  Future<void> get settled => _pending;

  Future<void> initialize() async {
    try {
      await PackStore.instance.initialize();
    } catch (_) {
      /* Classic audio works without optional download storage. */
    }
    WidgetsBinding.instance.addObserver(this);
    restoreSettings(await SharedPreferences.getInstance());
    _backend = AssetAudioBackend();
    _completion = _backend!.cueFinished.listen((_) => _cueEnded());
    // The opening screen may have selected its scene before initialization ended.
    _queue((backend) async {
      if (_audible) await backend.music(_bedVolume);
    });
  }

  void restoreSettings(SharedPreferences preferences) {
    _preferences = preferences;
    musicLevel = (_preferences!.getDouble('audio.music') ?? .35).clamp(0, 1);
    voiceLevel = (_preferences!.getDouble('audio.voice') ?? .85).clamp(0, 1);
    effectLevel = (_preferences!.getDouble('audio.effect') ?? .65).clamp(0, 1);
    muted = _preferences!.getBool('audio.muted') ?? false;
    narrationEnabled = _preferences!.getBool('audio.narration') ?? true;
    automaticNarrationPreferred =
        _preferences!.getBool('audio.automaticMDJ') ?? true;
    _voiceProfile = _findVoice(_preferences!.getString('audio.voiceProfile'));
    notifyListeners();
  }

  void selectVoice(String id) {
    final next = _findVoice(id);
    if (_voiceProfile.id == next.id) return;
    _voiceProfile = next;
    _saveSettings();
    notifyListeners();
  }

  void preferAutomaticNarration(bool value) {
    automaticNarrationPreferred = value;
    _saveSettings();
  }

  bool get canPreviewVoice =>
      _backend != null &&
      voiceProfile.supports('preview.wav') &&
      !muted &&
      _foreground &&
      narrationEnabled &&
      !_opening &&
      voiceLevel > 0;
  void previewVoice() {
    if (canPreviewVoice) _play('preview.wav', voice: true, preview: true);
  }

  bool get _audible => !muted && _foreground && scene != AudioScene.silent;
  double get _bedVolume => _audible ? musicLevel * (_ducked ? .2 : 1) : 0;

  void _queue(Future<void> Function(AudioBackend) action) {
    final backend = _backend;
    if (backend == null || _disposed) return;
    _pending = _pending.then((_) async {
      if (_disposed) return;
      try {
        await action(backend);
      } catch (failure) {
        missingPackIds = failure is MissingPackException
            ? [failure.packId]
            : const [];
        error = failure is MissingPackException
            ? failure.message
            : 'Lecture audio indisponible. Vérifie la sortie sonore puis réessaie.';
        _ducked = false;
        try {
          await backend.musicVolume(_bedVolume);
        } catch (_) {
          /* Sortie absente. */
        }
        if (!_disposed) notifyListeners();
      }
    });
  }

  void _setScene(AudioScene next) {
    if (scene == next) return;
    _cancelStory();
    scene = next;
    if (next != AudioScene.host) {
      _storm?.cancel();
      _storm = null;
      _weather = const VillageWeather();
      _weatherClock.stop();
      _lastThunder = null;
    }
    _lastCue = null;
    _currentVoice = null;
    _ducked = false;
    final epoch = ++_epoch;
    _fade++;
    _queue((backend) async {
      await backend.stop();
      if (epoch != _epoch || !_audible) return;
      await backend.music(0);
      _fadeIn(epoch);
    });
    notifyListeners();
  }

  void welcome() {
    _opening = false;
    _setScene(AudioScene.welcome);
    if (!_howled) {
      _howled = true;
      _welcomeHowl = Completer<void>();
      if (_backend == null || muted || effectLevel == 0) {
        _welcomeHowl!.complete();
      }
      _play('wolf_howl.mp3', voice: false);
    }
  }

  void opening() {
    _opening = true;
    _setScene(AudioScene.welcome);
  }

  void openingScratch(int strike) {
    if (_opening &&
        scene == AudioScene.welcome &&
        (strike == 1 || strike == 2)) {
      _play('claw_$strike.wav', voice: false);
    }
  }

  void silence() {
    _opening = false;
    _setScene(AudioScene.silent);
  }

  void room(Map<String, dynamic>? room, {required bool isHost}) {
    _opening = false;
    final voice = room?['narration_profile'] as String?;
    final next = voice == null ? null : _findVoice(voice);
    final automatic = room?['automatic_narration'] != false;
    if (_roomVoice?.id != next?.id || roomAutomatic != automatic) {
      _narrationGeneration++;
      _roomVoice = next;
      roomAutomatic = automatic;
      _cancelStory();
      _cueTicket++;
      _queue((backend) => backend.stopCue());
      notifyListeners();
    }
    if (room == null || !isHost) {
      _narrationRoom = null;
      _narrationRevision = -1;
      silence();
      return;
    }
    _setScene(AudioScene.host);
    final game = room['game'] as Map?;
    _updateWeather(game);
    if (game == null) {
      _narrationRoom = room['code'] as String?;
      _narrationRevision = -1;
      _lastCue = null;
      _currentVoice = null;
      return;
    }
    final phase = game['phase'] as String? ?? room['phase'] as String?;
    final potionId = '${room['code']}:${game['night']}';
    if (phase == 'witch' &&
        game['narration_events'] is List &&
        (room['game_host'] as Map?)?['potion_used'] == true &&
        _lastPotionCue != potionId) {
      _lastPotionCue = potionId;
      _story([(asset: 'witch_potion.wav', profile: 'old_witch')]);
    }
    if (game['narration_events'] is List) {
      final previousVoice = _currentVoice;
      final events = (game['narration_events'] as List).cast<Map>();
      if (_narrationRoom != room['code']) {
        _narrationRoom = room['code'] as String?;
        _narrationRevision = events.isEmpty
            ? -1
            : (events.last['revision'] as int) - 1;
      }
      if (phase == 'ended') {
        if (events.isNotEmpty) {
          _narrationRevision = events.last['revision'] as int;
        }
        _currentVoice = null;
        if (previousVoice != null) notifyListeners();
        return;
      }
      for (final event in events) {
        if ((event['revision'] as int) <= _narrationRevision) continue;
        _narrationRevision = event['revision'] as int;
        _currentVoice = event['cue'] as String;
        if (roomAutomatic) {
          final generation = _narrationGeneration;
          _story(
            [(asset: _currentVoice!, profile: voiceProfile.id)],
            automatic: true,
            isCurrent: () => generation == _narrationGeneration,
          );
        }
      }
      if (previousVoice != _currentVoice) notifyListeners();
      return;
    }
    if (!roomAutomatic) return;
    if (phase == 'witch' &&
        (room['game_host'] as Map?)?['potion_used'] == true &&
        _lastPotionCue != potionId) {
      _lastPotionCue = potionId;
      final witch = _profiles.where((p) => p.id == 'old_witch').firstOrNull;
      if (witch != null) {
        _play('witch_potion.wav', voice: true, profile: witch);
      }
      return;
    }
    if (game['night_menu'] == true) {
      if (_currentVoice != null) {
        _currentVoice = null;
        _cueTicket++;
        notifyListeners();
      }
      return;
    }
    final id =
        '${room['code']}:${game['night']}:${game['phase_revision']}:$phase';
    if (id == _lastCue) return;
    _lastCue = id;
    // The final ceremony is scheduled after the death cards, never twice here.
    if (phase == 'ended') {
      _currentVoice = null;
      notifyListeners();
      return;
    }
    final asset = '$phase.wav';
    if (!voiceAssets.contains(asset)) {
      if (_currentVoice != null) {
        _currentVoice = null;
        _cueTicket++;
        notifyListeners();
      }
      return;
    }
    _currentVoice = asset;
    _play(asset, voice: true);
  }

  static const voiceAssets = {
    'role_reveal.wav',
    'sleep.wav',
    'seer.wav',
    'wolves.wav',
    'witch.wav',
    'dawn.wav',
    'hunter.wav',
    'day.wav',
    'voting.wav',
    'vote_result.wav',
    'ended_village.wav',
    'ended_wolves.wav',
    'ended_draw.wav',
  };

  void _updateWeather(Map? game) {
    final next = VillageWeather.fromMap(game?['weather'] as Map?);
    final changed = next.session != _weather.session;
    _gamePaused = game?['paused'] == true;
    if (changed || next.elapsedMs != _weather.elapsedMs) {
      _weatherClock
        ..reset()
        ..start();
    }
    _weather = next;
    if (changed) {
      _lastThunder = null;
      final epoch = _epoch;
      _queue((backend) async {
        if (epoch == _epoch) await _applyWeather(backend);
      });
    }
    _scheduleStorm();
  }

  Future<void> _applyWeather(AudioBackend backend) async {
    try {
      await backend.weather(
        _audible &&
                scene == AudioScene.host &&
                _weather.raining &&
                effectLevel > 0
            ? 'rain_loop.wav'
            : null,
        effectLevel * .32 * (_ducked ? .25 : 1),
      );
    } catch (_) {
      // Une ambiance indisponible ne doit pas empêcher l'annonce d'un rôle.
      error = 'L’ambiance météo est indisponible sur cette sortie sonore.';
      if (!_disposed) notifyListeners();
    }
  }

  void _scheduleStorm() {
    if (_backend == null ||
        !_audible ||
        scene != AudioScene.host ||
        !_weather.storm ||
        effectLevel == 0) {
      _storm?.cancel();
      _storm = null;
      return;
    }
    _storm ??= Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _stormTick(),
    );
  }

  void _stormTick() {
    if (!_audible || _ducked || _gamePaused || scene != AudioScene.host) return;
    final event = _weather.thunderAt(
      _weather.elapsedMs + _weatherClock.elapsedMilliseconds,
    );
    if (event == null || event == _lastThunder) return;
    _lastThunder = event;
    final epoch = _epoch;
    _queue((backend) async {
      if (epoch == _epoch &&
          _audible &&
          !_ducked &&
          _weather.storm &&
          effectLevel > 0) {
        await backend.thunder(effectLevel * .65);
      }
    });
  }

  void _cancelStory() {
    final current = _cancelCurrentStory;
    if (current != null && !current.isCompleted) current.complete();
  }

  void stopDeathSpeech() {
    _deathTicket++;
    _cancelStory();
    _queue((backend) => backend.stopCue());
  }

  void deathSpeech(
    String? publicRole, {
    String? cause,
    String? edition,
    bool cursed = false,
    bool feminine = false,
  }) {
    final speech = deathSpeechFor(
      publicRole,
      cursed: cursed,
      feminine: feminine,
    );
    if (!_audible || scene != AudioScene.host) return;
    if (speech == null &&
        cause != 'hunter' &&
        !(cause == 'vote' && edition == 'intense')) {
      return;
    }
    stopDeathSpeech();
    final ticket = _deathTicket;
    _story([
      if (cause == 'hunter') (asset: 'hunter_volley.wav', profile: null),
      if (cause == 'hunter' && wolfRoleIds.contains(publicRole))
        (asset: 'wolf_fall.wav', profile: null),
      if (cause == 'vote' && edition == 'intense')
        (asset: 'sentence_electric.wav', profile: null),
      if (speech != null) (asset: speech.cue, profile: speech.profile),
    ], isCurrent: () => ticket == _deathTicket);
  }

  void revival() {
    stopDeathSpeech();
    final ticket = _deathTicket;
    _story(
      [(asset: 'revival.wav', profile: 'old_witch')],
      privateCue: true,
      isCurrent: () => ticket == _deathTicket,
    );
  }

  void ending(String? winner) {
    final ending = gameEndings[winner];
    _story([
      (
        asset: winner == 'wolves' ? 'ending_dark.wav' : 'ending_bright.wav',
        profile: null,
      ),
      if (ending != null) (asset: ending.cue, profile: ending.profile),
    ]);
  }

  void _story(
    List<({String asset, String? profile})> cues, {
    bool Function()? isCurrent,
    bool automatic = false,
    bool privateCue = false,
  }) {
    if (_backend == null ||
        _disposed ||
        (!(_audible && scene == AudioScene.host) &&
            !(privateCue && !muted && _foreground))) {
      return;
    }
    final epoch = _epoch;
    _stories++;
    _cueTicket++; // Cancel ordinary phase announcements waiting in the queue.
    _queue((backend) async {
      final cancel = Completer<void>();
      _cancelCurrentStory = cancel;
      try {
        for (final cue in cues) {
          if (epoch != _epoch ||
              (!_audible && !(privateCue && !muted && _foreground)) ||
              cancel.isCompleted ||
              (automatic && !roomAutomatic) ||
              isCurrent?.call() == false) {
            break;
          }
          final voice = cue.profile != null;
          final profile = voice
              ? _profiles.where((p) => p.id == cue.profile).firstOrNull
              : null;
          if (voice &&
              (!narrationEnabled ||
                  voiceLevel == 0 ||
                  profile?.supports(cue.asset) != true)) {
            continue;
          }
          if (!voice && effectLevel == 0) continue;
          if (backend is AssetAudioBackend &&
              !AssetAudioBackend.available(
                voice ? profile!.assetFor(cue.asset) : cue.asset,
              )) {
            final id = downloadablePackForAsset(
              voice ? profile!.assetFor(cue.asset) : cue.asset,
            );
            if (id != null) {
              missingPackIds = [id];
              error = MissingPackException(id).message;
              notifyListeners();
            }
            continue;
          }
          _ducked = true;
          _cueIsVoice = voice;
          _fade++;
          await backend.musicVolume(_bedVolume);
          await _applyWeather(backend);
          final finished = Completer<void>();
          final sub = backend.cueFinished.listen((_) {
            if (!finished.isCompleted) finished.complete();
          });
          try {
            await backend.cue(
              voice ? profile!.assetFor(cue.asset) : cue.asset,
              voice ? voiceLevel : effectLevel,
            );
            await Future.any([
              finished.future,
              cancel.future,
            ]).timeout(const Duration(seconds: 20));
          } finally {
            await sub.cancel();
          }
        }
      } finally {
        if (identical(_cancelCurrentStory, cancel)) _cancelCurrentStory = null;
        _stories--;
        if (_stories == 0) _cueEnded();
      }
    });
  }

  void replay() {
    if (scene == AudioScene.host && _currentVoice != null) {
      _play(_currentVoice!, voice: true);
    }
    if (scene == AudioScene.welcome) _play('wolf_howl.mp3', voice: false);
  }

  bool get canReplay =>
      scene == AudioScene.welcome ||
      scene == AudioScene.host &&
          _currentVoice != null &&
          voiceProfile.supports(_currentVoice!);

  void _play(
    String asset, {
    required bool voice,
    VoiceProfile? profile,
    bool preview = false,
  }) {
    if (_stories > 0 && voice && !preview) return;
    if (voice && !(profile ?? voiceProfile).supports(asset)) return;
    final epoch = _epoch;
    final ticket = ++_cueTicket;
    _queue((backend) async {
      if (epoch != _epoch ||
          ticket != _cueTicket ||
          (!_audible && !(preview && !muted && _foreground && !_opening)) ||
          (voice && !narrationEnabled) ||
          (voice ? voiceLevel : effectLevel) == 0 ||
          (voice && !(profile ?? voiceProfile).supports(asset))) {
        return;
      }
      _ducked = true;
      _cueIsVoice = voice;
      _fade++;
      await backend.musicVolume(_bedVolume);
      if (scene == AudioScene.host) await _applyWeather(backend);
      if (asset == 'wolf_howl.mp3' && scene == AudioScene.welcome) {
        _welcomeHowlActive = true;
      }
      await backend.cue(
        voice ? (profile ?? voiceProfile).assetFor(asset) : asset,
        voice ? voiceLevel : effectLevel,
      );
      if (error != null) {
        error = null;
        missingPackIds = const [];
        notifyListeners();
      }
    });
  }

  void _cueEnded() {
    if (_welcomeHowlActive) {
      _welcomeHowlActive = false;
      if (_welcomeHowl?.isCompleted == false) _welcomeHowl!.complete();
    }
    if (_stories > 0) return;
    _ducked = false;
    _fadeIn(_epoch, from: musicLevel * .2);
    _queue(_applyWeather);
  }

  void _fadeIn(int epoch, {double from = 0}) {
    final fade = ++_fade;
    unawaited(() async {
      final steps = fadeDuration == Duration.zero ? 1 : 30;
      for (var step = 1; step <= steps; step++) {
        if (fadeDuration != Duration.zero) {
          await Future<void>.delayed(fadeDuration ~/ steps);
        }
        if (_disposed || fade != _fade || epoch != _epoch || !_audible) return;
        final volume = from + (_bedVolume - from) * step / steps;
        _queue((backend) async {
          if (fade == _fade && epoch == _epoch && _audible) {
            await backend.musicVolume(volume);
          }
        });
      }
    }());
  }

  void levels({
    double? music,
    double? voice,
    double? effects,
    bool? mute,
    bool? narration,
  }) {
    if (mute == true || narration == false || voice == 0 || effects == 0) {
      _cancelStory();
    }
    narrationEnabled = narration ?? narrationEnabled;
    musicLevel = (music ?? musicLevel).clamp(0, 1);
    voiceLevel = (voice ?? voiceLevel).clamp(0, 1);
    effectLevel = (effects ?? effectLevel).clamp(0, 1);
    final wasMuted = muted;
    muted = mute ?? muted;
    _fade++;
    final epoch = _epoch;
    _queue((backend) async {
      if (epoch != _epoch) return;
      if (!_audible) {
        await backend.stop();
        _ducked = false;
      } else if (wasMuted) {
        await backend.music(_bedVolume);
        await _applyWeather(backend);
      } else {
        final cueLevel = _cueIsVoice
            ? (narrationEnabled ? voiceLevel : 0.0)
            : effectLevel;
        if (cueLevel == 0) {
          await backend.stopCue();
          _ducked = false;
        } else {
          await backend.cueVolume(cueLevel);
        }
        await backend.musicVolume(_bedVolume);
        await _applyWeather(backend);
      }
    });
    _scheduleStorm();
    _saveSettings();
    notifyListeners();
  }

  void _saveSettings() {
    _save?.cancel();
    _save = Timer(const Duration(milliseconds: 300), () async {
      await _preferences?.setDouble('audio.music', musicLevel);
      await _preferences?.setDouble('audio.voice', voiceLevel);
      await _preferences?.setDouble('audio.effect', effectLevel);
      await _preferences?.setBool('audio.muted', muted);
      await _preferences?.setBool('audio.narration', narrationEnabled);
      await _preferences?.setBool(
        'audio.automaticMDJ',
        automaticNarrationPreferred,
      );
      await _preferences?.setString('audio.voiceProfile', _voiceProfile.id);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground == foreground) return;
    _cancelStory();
    _foreground = foreground;
    _epoch++;
    _fade++;
    _ducked = false;
    _queue((backend) async {
      await backend.stop();
      if (_audible) await backend.music(_bedVolume);
      if (_audible) await _applyWeather(backend);
    });
    _scheduleStorm();
    // Ne jamais rejouer une narration après un retour au premier plan.
  }

  @override
  void dispose() {
    _cancelStory();
    _disposed = true;
    _fade++;
    _save?.cancel();
    _storm?.cancel();
    _weatherClock.stop();
    _completion?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    final backend = _backend;
    if (backend != null) unawaited(_pending.then((_) => backend.dispose()));
    super.dispose();
  }
}
