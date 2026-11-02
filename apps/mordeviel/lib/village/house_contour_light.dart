import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../services/immersion_preferences.dart';
import 'house_sprite_geometry.dart';
import 'intense_house_contours.g.dart';

/// A faint outline and a short travelling highlight follow the PNG silhouette.
/// No rectangular border, additional bitmap or information about hidden roles.
class HouseContourLight extends StatefulWidget {
  const HouseContourLight({
    super.key,
    required this.child,
    required this.state,
    this.phase = 0,
    this.paused = false,
  });
  final Widget child;
  final String state;
  final double phase;
  final bool paused;
  @override
  State<HouseContourLight> createState() => _HouseContourLightState();
}

class _HouseContourLightState extends State<HouseContourLight>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _clock;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    _clock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    WidgetsBinding.instance.addObserver(this);
    ImmersionPreferences.instance.addListener(_sync);
  }

  void _sync() {
    if (!mounted) return;
    final animate =
        _foreground &&
        !widget.paused &&
        TickerMode.valuesOf(context).enabled &&
        !ImmersionPreferences.instance.reduced(context);
    if (animate && !_clock.isAnimating) {
      _clock.repeat();
    } else if (!animate) {
      _clock.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant HouseContourLight oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ImmersionPreferences.instance.removeListener(_sync);
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _Contour(_clock, widget.state, widget.phase),
    child: RepaintBoundary(child: widget.child),
  );
}

class _Contour extends CustomPainter {
  _Contour(this.clock, this.state, this.phase) : super(repaint: clock);
  final Animation<double> clock;
  final String state;
  final double phase;
  Size? _size;
  late Path _outline;
  late ui.PathMetric _metric;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (_size != size) {
      _size = size;
      final geometry = intenseHouseSpriteGeometry[state]!;
      final scale = math.min(
        size.width / geometry.visibleWidth,
        size.height / geometry.visibleHeight,
      );
      final width = geometry.visibleWidth * scale,
          height = geometry.visibleHeight * scale;
      final origin = Offset((size.width - width) / 2, size.height - height);
      _outline = Path()
        ..addPolygon([
          for (final point in intenseHouseContours[state]!)
            origin + Offset(point.dx * width, point.dy * height),
        ], true);
      _metric = _outline.computeMetrics().first;
    }
    final bright = state == 'night';
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFB5DBEE).withValues(alpha: bright ? .38 : .22);
    canvas.drawPath(_outline, line);
    final start = ((clock.value + phase) % 1) * _metric.length;
    final end = start + _metric.length * .12;
    final highlight = _metric.extractPath(start, math.min(end, _metric.length));
    if (end > _metric.length) {
      highlight.addPath(
        _metric.extractPath(0, end - _metric.length),
        Offset.zero,
      );
    }
    canvas.drawPath(
      highlight,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2)
        ..color = const Color(0xFFE6D5A5).withValues(alpha: bright ? .42 : .28),
    );
    canvas.drawPath(
      highlight,
      line
        ..strokeWidth = 1.6
        ..color = const Color(0xFFFFEDC3).withValues(alpha: bright ? .75 : .50),
    );
  }

  @override
  bool shouldRepaint(covariant _Contour old) =>
      old.clock != clock || old.state != state || old.phase != phase;
}
