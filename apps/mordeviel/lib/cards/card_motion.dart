import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import '../services/immersion_preferences.dart';

const cardSpring = SpringDescription(mass: 1, stiffness: 170, damping: 25);
const cardTiltSpring = SpringDescription(mass: 1, stiffness: 360, damping: 32);
const cardTurnSpring = SpringDescription(mass: 1, stiffness: 100, damping: 20);

bool cardFaceIsBack(double halfTurns) => math.cos(halfTurns * math.pi) < 0;

/// A quick flick carries the card farther, with at most two extra revolutions.
/// A slow release returns to the closest readable face.
double cardTurnTarget(double halfTurns, double velocity) =>
    (halfTurns + velocity.clamp(-12.0, 12.0) * .24).roundToDouble();

class CardMotion extends StatefulWidget {
  const CardMotion({
    super.key,
    required this.child,
    required this.onDismiss,
    required this.onPeek,
    required this.canPeek,
    this.enabled = true,
    this.halfTurns = 0,
    this.onTurnStart,
    this.onTurnUpdate,
    this.onTurnEnd,
    this.onTurnCancel,
  });
  final Widget child;
  final VoidCallback onDismiss;
  final ValueChanged<bool> onPeek;
  final bool canPeek;
  final bool enabled;
  final double halfTurns;
  final VoidCallback? onTurnStart, onTurnCancel;
  final ValueChanged<double>? onTurnUpdate, onTurnEnd;
  @override
  State<CardMotion> createState() => _CardMotionState();
}

class _CardMotionState extends State<CardMotion>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _tiltX, _tiltY;
  int? _pointer;
  bool _turning = false, _turnedDuringPointer = false;
  double _pivot = 0, _verticalTravel = 0;
  double get _width => (context.findRenderObject() as RenderBox).size.width;
  @override
  void initState() {
    super.initState();
    _tiltX = AnimationController.unbounded(vsync: this);
    _tiltY = AnimationController.unbounded(vsync: this);
    WidgetsBinding.instance.addObserver(this);
  }

  void _aim(AnimationController axis, double target) {
    if (ImmersionPreferences.instance.reduced(context)) {
      axis.value = 0;
      return;
    }
    axis.animateWith(
      SpringSimulation(
        cardTiltSpring,
        axis.value,
        target,
        axis.velocity.clamp(-4.0, 4.0),
      ),
    );
  }

  void _down(PointerDownEvent event) {
    if (!widget.enabled || _pointer != null) return;
    _pointer = event.pointer;
    _turnedDuringPointer = false;
    widget.onTurnStart?.call();
    setState(() {
      // Keep the gesture plane fixed while the artwork pivots under the finger.
      _pivot = (event.localPosition.dx / _width * 2 - 1).clamp(-1.0, 1.0) * .3;
    });
    _move(event);
  }

  void _move(PointerEvent event) {
    if (!widget.enabled || _pointer != event.pointer) return;
    final size = (context.findRenderObject() as RenderBox).size;
    final p = event.localPosition;
    _aim(_tiltX, _turning ? 0 : (p.dx / size.width - .5).clamp(-.5, .5) * .6);
    _aim(_tiltY, (p.dy / size.height - .5).clamp(-.5, .5) * .5);
  }

  void _release(PointerEvent event) {
    if (_pointer != event.pointer) return;
    _pointer = null;
    widget.onPeek(false);
    _aim(_tiltX, 0);
    _aim(_tiltY, 0);
    if (!_turnedDuringPointer) widget.onTurnEnd?.call(0);
  }

  void _cancelTurn() {
    if (!_turning) return;
    _turning = false;
    widget.onTurnCancel?.call();
  }

  @override
  void didUpdateWidget(covariant CardMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) _reset();
  }

  void _reset() {
    _pointer = null;
    _turning = false;
    _tiltX.value = 0;
    _tiltY.value = 0;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _reset();
      widget.onPeek(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tiltX.dispose();
    _tiltY.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: _release,
    onPointerCancel: (event) {
      _release(event);
      _turning = false;
      widget.onTurnCancel?.call();
    },
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: widget.canPeek && widget.enabled
          ? (_) {
              ImmersionPreferences.instance.touch();
              widget.onPeek(true);
            }
          : null,
      onLongPressEnd: widget.canPeek && widget.enabled
          ? (_) => widget.onPeek(false)
          : null,
      onLongPressCancel: widget.canPeek ? () => widget.onPeek(false) : null,
      onLongPressMoveUpdate: widget.canPeek
          ? (details) {
              if (details.offsetFromOrigin.distance > 80) widget.onPeek(false);
            }
          : null,
      onHorizontalDragStart: widget.enabled && widget.onTurnStart != null
          ? (_) {
              _turning = true;
              _turnedDuringPointer = true;
              widget.onPeek(false);
              _aim(_tiltX, 0);
            }
          : null,
      onHorizontalDragUpdate: widget.enabled && widget.onTurnUpdate != null
          ? (details) => widget.onTurnUpdate!(
              (details.primaryDelta ?? 0) / _width * 1.15,
            )
          : null,
      onHorizontalDragEnd: widget.enabled && widget.onTurnEnd != null
          ? (details) {
              _turning = false;
              widget.onTurnEnd!(
                ((details.primaryVelocity ?? 0) / _width * 1.15).clamp(
                  -12.0,
                  12.0,
                ),
              );
            }
          : null,
      onHorizontalDragCancel: _cancelTurn,
      onVerticalDragStart: widget.enabled ? (_) => _verticalTravel = 0 : null,
      onVerticalDragUpdate: widget.enabled
          ? (details) => _verticalTravel += details.primaryDelta ?? 0
          : null,
      onVerticalDragEnd: widget.enabled
          ? (details) {
              final height =
                  (context.findRenderObject() as RenderBox).size.height;
              if (_verticalTravel > height * .24 &&
                  (details.primaryVelocity ?? 0) > 350) {
                widget.onDismiss();
              }
            }
          : null,
      child: AnimatedBuilder(
        animation: Listenable.merge([_tiltX, _tiltY]),
        child: RepaintBoundary(child: widget.child),
        builder: (context, child) {
          final angle = widget.halfTurns * math.pi;
          final facingAngle =
              angle - (cardFaceIsBack(widget.halfTurns) ? math.pi : 0);
          return Transform(
            key: const ValueKey('card-pose'),
            alignment: Alignment(_pivot, 0),
            transform: Matrix4.identity()
              ..setEntry(3, 2, .001)
              ..rotateX(-_tiltY.value)
              ..rotateY(facingAngle + _tiltX.value)
              ..rotateZ(_tiltX.value * _tiltY.value * .32),
            child: child,
          );
        },
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
