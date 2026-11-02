import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../services/immersion_preferences.dart';

const cardSpring = SpringDescription(mass: 1, stiffness: 170, damping: 25);

class CardMotion extends StatefulWidget {
  const CardMotion({
    super.key,
    required this.child,
    required this.onDismiss,
    required this.onPeek,
    required this.canPeek,
  });
  final Widget child;
  final VoidCallback onDismiss;
  final ValueChanged<bool> onPeek;
  final bool canPeek;
  @override
  State<CardMotion> createState() => _CardMotionState();
}

class _CardMotionState extends State<CardMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spring;
  Offset _tilt = Offset.zero, _from = Offset.zero;
  @override
  void initState() {
    super.initState();
    _spring = AnimationController.unbounded(vsync: this)
      ..addListener(() => setState(() => _tilt = _from * (1 - _spring.value)));
  }

  void _move(PointerEvent event) {
    if (ImmersionPreferences.instance.reduced(context)) return;
    _spring.stop();
    final box = context.findRenderObject() as RenderBox;
    final p = box.globalToLocal(event.position);
    setState(
      () => _tilt = Offset(
        (p.dx / box.size.width - .5).clamp(-.5, .5) * .16,
        (p.dy / box.size.height - .5).clamp(-.5, .5) * .16,
      ),
    );
  }

  void _release() {
    widget.onPeek(false);
    _from = _tilt;
    _spring.value = 0;
    if (ImmersionPreferences.instance.reduced(context)) {
      setState(() => _tilt = Offset.zero);
    } else {
      _spring.animateWith(SpringSimulation(cardSpring, 0, 1, 0));
    }
  }

  @override
  void dispose() {
    _spring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _move,
    onPointerMove: _move,
    onPointerUp: (_) => _release(),
    onPointerCancel: (_) => _release(),
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: widget.canPeek
          ? (_) {
              ImmersionPreferences.instance.touch();
              widget.onPeek(true);
            }
          : null,
      onLongPressEnd: widget.canPeek ? (_) => widget.onPeek(false) : null,
      onLongPressCancel: () => widget.onPeek(false),
      onLongPressMoveUpdate: (details) {
        if (details.offsetFromOrigin.distance > 80) widget.onPeek(false);
      },
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 250) widget.onDismiss();
      },
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .001)
          ..rotateX(-_tilt.dy)
          ..rotateY(_tilt.dx),
        child: widget.child,
      ),
    ),
  );
}

class CardFinish extends StatefulWidget {
  const CardFinish({super.key, required this.child, required this.horror});
  final Widget child;
  final bool horror;
  @override
  State<CardFinish> createState() => _CardFinishState();
}

class _CardFinishState extends State<CardFinish>
    with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );
  void _sync() {
    if (!mounted) return;
    if (ImmersionPreferences.instance.reduced(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.forward();
    }
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    ImmersionPreferences.instance.addListener(_sync);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void dispose() {
    ImmersionPreferences.instance.removeListener(_sync);
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      Positioned.fill(
        child: IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(painter: _Foil(_clock, widget.horror)),
          ),
        ),
      ),
    ],
  );
}

class _Foil extends CustomPainter {
  _Foil(this.clock, this.horror) : super(repaint: clock);
  final Animation<double> clock;
  final bool horror;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(18)));
    final x = (clock.value * 2.4 - .7) * size.width;
    final glow = horror ? const Color(0xFF90C4A7) : const Color(0xFFFFD889);
    canvas.drawRect(
      rect,
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.transparent,
                glow.withValues(alpha: .03),
                Colors.white.withValues(alpha: .13),
                glow.withValues(alpha: .04),
                Colors.transparent,
              ],
              stops: const [0, .4, .5, .6, 1],
            ).createShader(
              Rect.fromLTWH(
                x,
                -size.height * .2,
                size.width * .7,
                size.height * 1.4,
              ),
            ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(18)),
      Paint()
        ..color = glow.withValues(
          alpha: .24 + .08 * math.sin(clock.value * math.pi * 2),
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Foil old) =>
      old.horror != horror || old.clock != clock;
}

class PeekCornerClip extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(size.width * .12, size.height)
    ..lineTo(size.width, size.height * .48)
    ..lineTo(size.width, size.height)
    ..close();
  @override
  bool shouldReclip(covariant PeekCornerClip oldClipper) => false;
}
