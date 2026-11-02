import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/immersion_preferences.dart';

class VillageLife extends StatefulWidget {
  const VillageLife({
    super.key,
    required this.night,
    required this.plots,
    this.paused = false,
  });
  final bool night, paused;
  final List<(Offset, double)> plots;
  @override
  State<VillageLife> createState() => _VillageLifeState();
}

class _VillageLifeState extends State<VillageLife>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );
  bool _foreground = true;
  void _sync() {
    if (!mounted) return;
    if (_foreground &&
        !widget.paused &&
        TickerMode.valuesOf(context).enabled &&
        !ImmersionPreferences.instance.reduced(context)) {
      if (!_clock.isAnimating) _clock.repeat();
    } else {
      _clock.stop();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ImmersionPreferences.instance.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant VillageLife old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    ImmersionPreferences.instance.removeListener(_sync);
    WidgetsBinding.instance.removeObserver(this);
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _LifePainter(_clock, widget.night, widget.plots),
        ),
      ),
    ),
  );
}

class _LifePainter extends CustomPainter {
  _LifePainter(this.clock, this.night, this.plots) : super(repaint: clock);
  final Animation<double> clock;
  final bool night;
  final List<(Offset, double)> plots;
  @override
  void paint(Canvas canvas, Size size) {
    final seconds = clock.value * 24;
    for (var i = 0; i < plots.length; i++) {
      final (anchor, extent) = plots[i];
      final origin = Offset(anchor.dx * size.width, anchor.dy * size.height);
      if (night) {
        final center = origin - Offset(0, extent * .23);
        final rect = Rect.fromCenter(
          center: center,
          width: extent * .46,
          height: extent * .23,
        );
        canvas.drawOval(
          rect,
          Paint()
            ..shader = RadialGradient(
              colors: [
                Color.fromRGBO(
                  255,
                  196,
                  99,
                  .10 + .025 * math.sin(seconds * .8 + i),
                ),
                const Color(0x00FFC463),
              ],
            ).createShader(rect),
        );
      }
      if (i % 3 != 0) continue;
      for (var p = 0; p < 3; p++) {
        final age = ((seconds / 5 + p / 3 + i * .13) % 1);
        final center =
            origin +
            Offset(
              -extent * .12 + math.sin(age * 4 + i) * extent * age * .15,
              -extent * (.82 + age * .5),
            );
        canvas.drawOval(
          Rect.fromCenter(
            center: center,
            width: extent * (.04 + age * .14),
            height: extent * (.03 + age * .11),
          ),
          Paint()
            ..color = Color.fromRGBO(
              184,
              192,
              197,
              (1 - age) * (night ? .09 : .15),
            )
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LifePainter old) =>
      old.night != night || old.plots != plots;
}
