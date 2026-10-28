import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:local_host/local_host.dart';

class WeatherOverlay extends StatefulWidget {
  const WeatherOverlay({super.key, required this.weather});
  final VillageWeather weather;
  @override
  State<WeatherOverlay> createState() => _WeatherOverlayState();
}

class _WeatherOverlayState extends State<WeatherOverlay>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _frames;
  final _elapsed = Stopwatch()..start();
  bool _foreground = true, _reduced = false, _visible = true;
  int _anchor = 0;
  @override
  void initState() {
    super.initState();
    _anchor = widget.weather.elapsedMs;
    _frames = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    );
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant WeatherOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weather.elapsedMs != widget.weather.elapsedMs ||
        oldWidget.weather.session != widget.weather.session) {
      _anchor = widget.weather.elapsedMs;
      _elapsed.reset();
    }
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    _visible = TickerMode.valuesOf(context).enabled;
    _sync();
  }

  void _sync() {
    if (_foreground &&
        _visible &&
        !_reduced &&
        (widget.weather.raining ||
            widget.weather.rainbow ||
            widget.weather.snowing)) {
      if (!_frames.isAnimating) _frames.repeat();
    } else {
      _frames.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _frames.dispose();
    _elapsed.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weather = widget.weather;
    if (!weather.raining && !weather.rainbow && !weather.snowing) {
      return const SizedBox.expand();
    }
    return IgnorePointer(
      child: Semantics(
        image: true,
        label: weather.snowing
            ? 'Neige sur le village'
            : weather.storm
            ? 'Orage nocturne'
            : weather.raining
            ? 'Pluie nocturne'
            : 'Lueur d’arc-en-ciel',
        child: RepaintBoundary(
          child: CustomPaint(
            willChange: !_reduced,
            painter: _WeatherPainter(
              weather: weather,
              reduced: _reduced,
              elapsed: () => _anchor + _elapsed.elapsedMilliseconds,
              frames: _frames,
            ),
          ),
        ),
      ),
    );
  }
}

class _WeatherPainter extends CustomPainter {
  _WeatherPainter({
    required this.weather,
    required this.reduced,
    required this.elapsed,
    required Listenable frames,
  }) : super(repaint: frames);
  final VillageWeather weather;
  final bool reduced;
  final int Function() elapsed;
  double _hash(int i) {
    final n = math.sin(i * 127.1 + weather.seed * .001) * 43758.5453;
    return n - n.floorToDouble();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ms = reduced ? 0 : elapsed();
    final t = ms / 1000;
    if (weather.snowing) {
      final snow = Paint();
      for (var i = 0; i < (reduced ? 35 : 100); i++) {
        final depth = .35 + _hash(i + 100) * .65;
        final drift = math.sin(t * .35 + i) * .025;
        final x =
            ((_hash(i) + t * .008 * depth + drift) % 1.1 - .05) * size.width;
        final y =
            ((_hash(i + 200) + t * .045 * depth) % 1.1 - .05) * size.height;
        snow.color = const Color(
          0xFFF1F7FF,
        ).withValues(alpha: .25 + depth * .55);
        canvas.drawCircle(Offset(x, y), .7 + depth * 1.8, snow);
      }
    }
    if (weather.raining) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(weather.storm ? 0x38202C4F : 0x2223344A),
              Colors.transparent,
            ],
          ).createShader(Offset.zero & size),
      );
      final drops = reduced
          ? 28
          : weather.storm
          ? 115
          : 75;
      final rain = Paint()..strokeCap = StrokeCap.round;
      for (var i = 0; i < drops; i++) {
        final depth = .45 + _hash(i + 100) * .55;
        final x = ((_hash(i) + t * .035 * depth) % 1.2 - .1) * size.width;
        final y = ((_hash(i + 200) + t * .72 * depth) % 1.2 - .1) * size.height;
        rain
          ..color = const Color(0xFFC2DBEC).withValues(alpha: .12 + depth * .15)
          ..strokeWidth = .6 + depth * .6;
        canvas.drawLine(
          Offset(x, y),
          Offset(x - 4 * depth, y + 14 * depth),
          rain,
        );
      }
      if (!reduced) {
        final flash = weather.lightningAt(ms);
        if (flash > 0) {
          canvas.drawRect(
            Offset.zero & size,
            Paint()..color = const Color(0xFFE0E8FF).withValues(alpha: flash),
          );
        }
      }
    }
    if (weather.rainbow) {
      final strength = reduced ? .25 : .25 + .045 * math.sin(t * .25);
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
            center: Alignment(.7 + .03 * math.sin(t * .1), -.7),
            radius: 1,
            colors: [
              const Color(0xFFFFE6AA).withValues(alpha: strength * .65),
              Colors.transparent,
            ],
          ).createShader(Offset.zero & size),
      );
      final width = size.width * 1.25;
      final rect = Rect.fromCenter(
        center: Offset(size.width * .58, size.height * .63),
        width: width,
        height: width * .86,
      );
      canvas.drawArc(
        rect,
        math.pi,
        math.pi,
        false,
        Paint()
          ..color = const Color(0xFFFFEDC2).withValues(alpha: strength * .75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 25
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
      const colors = [
        Color(0xFFFF938A),
        Color(0xFFFFC579),
        Color(0xFFFFE59B),
        Color(0xFFA8DDB3),
        Color(0xFFA0C8ED),
        Color(0xFFC6B2E4),
      ];
      for (var i = 0; i < colors.length; i++) {
        canvas.drawArc(
          rect.deflate(i * 4),
          math.pi,
          math.pi,
          false,
          Paint()
            ..color = colors[i].withValues(alpha: strength)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_WeatherPainter old) =>
      old.weather != weather || old.reduced != reduced;
}
