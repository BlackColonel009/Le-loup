import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import '../audio/classic_audio.dart';
import '../content/pack_store.dart';
import '../services/immersion_preferences.dart';
import 'owl_flight.dart';

class HorrorPreferences extends ChangeNotifier {
  static final instance = HorrorPreferences();
  bool scares = true;
  Future<void> initialize() async {
    scares =
        (await SharedPreferences.getInstance()).getBool('horror_scares') ??
        true;
    notifyListeners();
  }

  Future<void> setScares(bool value) async {
    scares = value;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setBool(
      'horror_scares',
      value,
    );
  }
}

/// Decorative timing uses only a public seed, never roles or secret actions.
class HorrorAmbience extends StatefulWidget {
  const HorrorAmbience({
    super.key,
    required this.night,
    required this.seed,
    this.paused = false,
    this.camera,
    this.world = const Size(3072, 2048),
  });
  final bool night, paused;
  final int seed;
  final TransformationController? camera;
  final Size world;
  @override
  State<HorrorAmbience> createState() => _HorrorAmbienceState();
}

class _HorrorAmbienceState extends State<HorrorAmbience>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 120),
  )..addListener(_sound);
  AudioPlayer? _player;
  String? _lastSound;
  bool _foreground = true;
  bool get _allowed =>
      _foreground &&
      !widget.paused &&
      HorrorPreferences.instance.scares &&
      !ImmersionPreferences.instance.reduced(context) &&
      TickerMode.valuesOf(context).enabled;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HorrorPreferences.instance.addListener(_sync);
    ImmersionPreferences.instance.addListener(_sync);
    ClassicAudio.instance.addListener(_audioLevels);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant HorrorAmbience oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.night && !widget.night) {
      _player?.stop();
      _lastSound = null;
    }
    if (oldWidget.seed != widget.seed || !oldWidget.night && widget.night) {
      _clock.value = (widget.seed % 7) / 120;
      _lastSound = null;
    }
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _audioLevels() {
    final a = ClassicAudio.instance;
    _player?.setVolume(
      a.muted || a.scene != AudioScene.host ? 0 : a.effectLevel * .45,
    );
  }

  void _sync() {
    if (!mounted) return;
    if (_allowed) {
      if (!_clock.isAnimating) _clock.repeat();
    } else {
      _clock.stop();
      _player?.stop();
    }
    setState(() {});
  }

  void _sound() {
    if (!widget.night) return;
    final seconds = _clock.value * 120;
    final cue = seconds >= owlFlightStart + 1 && seconds < owlFlightStart + 4
        ? 'owl.wav'
        : seconds >= 72 && seconds < 75
        ? 'witch_laugh.wav'
        : null;
    if (cue == null) {
      _lastSound = null;
      return;
    }
    if (cue == _lastSound || !_allowed) return;
    _lastSound = cue;
    final a = ClassicAudio.instance;
    final path = PackStore.instance.pathFor('assets/audio/horror/$cue');
    if (path != null &&
        !a.muted &&
        a.effectLevel > 0 &&
        a.scene == AudioScene.host) {
      (_player ??= AudioPlayer())
          .play(DeviceFileSource(path), volume: a.effectLevel * .45)
          .catchError((Object _) {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HorrorPreferences.instance.removeListener(_sync);
    ImmersionPreferences.instance.removeListener(_sync);
    ClassicAudio.instance.removeListener(_audioLevels);
    _clock.dispose();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_allowed) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _clock,
            if (widget.camera != null) widget.camera!,
          ]),
          builder: (context, _) {
            final seconds = _clock.value * 120;
            return Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _BatsAndFog(seconds, widget.seed, widget.night),
                ),
                if (widget.night)
                  Positioned.fill(
                    child: OwlFlight(
                      seconds: seconds,
                      camera: widget.camera,
                      world: widget.world,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

double horrorBatProgress(double seconds, {required bool night}) {
  final first = night ? 12 : 40, second = night ? 54 : 100;
  if (seconds >= first && seconds < first + 8) return (seconds - first) / 8;
  if (seconds >= second && seconds < second + 8) return (seconds - second) / 8;
  return -1;
}

class _BatsAndFog extends CustomPainter {
  const _BatsAndFog(this.seconds, this.seed, this.night);
  final double seconds;
  final int seed;
  final bool night;
  @override
  void paint(Canvas canvas, Size size) {
    final fog = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0x004DA8A0),
          const Color(0x234DA8A0),
          const Color(0x004DA8A0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    for (var i = 0; i < (night ? 3 : 0); i++) {
      final y = size.height * (.3 + i * .23) + math.sin(seconds / 9 + i) * 15;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * .5 + math.sin(seconds / 20 + i) * 80, y),
          width: size.width * 1.5,
          height: 60,
        ),
        fog,
      );
    }
    final passage = horrorBatProgress(seconds, night: night);
    if (passage < 0) return;
    final paint = Paint()..color = const Color(0xE50A1019);
    for (var i = 0; i < 9; i++) {
      final x = -120 + passage * (size.width + 260) - (i % 3) * 28;
      final y =
          size.height * .24 + (i ~/ 3) * 23 + math.sin(seconds * 3 + i) * 10;
      final flap = math.sin(seconds * 14 + i) * 6;
      final path = Path()
        ..moveTo(x, y + 3)
        ..quadraticBezierTo(x - 7, y - 7 - flap, x - 20, y - 5 - flap)
        ..lineTo(x - 11, y + 4)
        ..lineTo(x - 5, y + 1)
        ..lineTo(x, y + 6)
        ..lineTo(x + 5, y + 1)
        ..lineTo(x + 11, y + 4)
        ..lineTo(x + 20, y - 5 - flap)
        ..quadraticBezierTo(x + 7, y - 7 - flap, x, y + 3)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BatsAndFog oldDelegate) =>
      seconds != oldDelegate.seconds || seed != oldDelegate.seed;
}
