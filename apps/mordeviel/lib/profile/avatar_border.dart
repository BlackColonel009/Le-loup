import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/immersion_preferences.dart';
import '../content/content_image.dart';
import 'border_catalog.g.dart';
export 'border_catalog.g.dart';

Map<String, Object>? avatarBorder(String? id) => avatarBorderCatalog
    .where((b) => b['id'] == id && b['effect'] != 'none')
    .firstOrNull;

/// Native animated rings and downloaded illustrated frames share this wrapper.
class AnimatedAvatarBorder extends StatefulWidget {
  const AnimatedAvatarBorder({
    super.key,
    required this.border,
    required this.child,
    this.animate = true,
  });
  final Map border;
  final Widget child;
  final bool animate;
  @override
  State<AnimatedAvatarBorder> createState() => _AnimatedAvatarBorderState();
}

class _AnimatedAvatarBorderState extends State<AnimatedAvatarBorder>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _turn;
  bool _reduced = false, _paused = false, _tickerEnabled = true;
  @override
  void initState() {
    super.initState();
    _turn = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );
    WidgetsBinding.instance.addObserver(this);
    ImmersionPreferences.instance.addListener(_sync);
    _paused =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = ImmersionPreferences.instance.reduced(context);
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _sync();
  }

  @override
  void didUpdateWidget(AnimatedAvatarBorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.animate &&
        widget.border['effect'] != 'artwork' &&
        !_reduced &&
        !ImmersionPreferences.instance.lightEffects &&
        !_paused &&
        _tickerEnabled) {
      if (!_turn.isAnimating) _turn.repeat();
    } else {
      _turn.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ImmersionPreferences.instance.removeListener(_sync);
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.border['effect'] == 'artwork') {
      final opening = (widget.border['opening'] as List).cast<num>();
      return RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, bounds) {
            final side = math.min(bounds.maxWidth, bounds.maxHeight);
            final dx = (bounds.maxWidth - side) / 2;
            final dy = (bounds.maxHeight - side) / 2;
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: dx + side * opening[0],
                  top: dy + side * opening[1],
                  width: side * opening[2],
                  height: side * opening[3],
                  child: ClipOval(child: widget.child),
                ),
                IgnorePointer(
                  child: ContentImage(
                    widget.border['asset'] as String,
                    fit: BoxFit.contain,
                    autoDownload: true,
                    cacheWidth:
                        (bounds.maxWidth *
                                MediaQuery.devicePixelRatioOf(context))
                            .ceil()
                            .clamp(96, 768),
                  ),
                ),
              ],
            );
          },
        ),
      );
    }
    return RepaintBoundary(
      child: CustomPaint(
        foregroundPainter: _BorderPainter(widget.border, _turn),
        child: widget.child,
      ),
    );
  }
}

class _BorderPainter extends CustomPainter {
  _BorderPainter(this.border, this.turn) : super(repaint: turn);
  final Map border;
  final Animation<double> turn;
  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    if (side <= 0) return;
    final colors = (border['colors'] as List)
        .map(
          (v) => Color(
            0xFF000000 | int.parse((v as String).substring(1), radix: 16),
          ),
        )
        .toList();
    final center = size.center(Offset.zero), radius = side / 2 - 2;
    final width = (side * .024).clamp(1.2, 3.3);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final angle = turn.value * math.pi * 2;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..color = colors[1].withValues(alpha: .32);
    canvas.drawCircle(center, radius, base);
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..shader = SweepGradient(
        colors: [...colors, colors.first],
        transform: GradientRotation(angle),
      ).createShader(rect);
    canvas.drawCircle(center, radius - width * .6, ring);
    final spark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width * .72
      ..color = const Color(0xFFFFF1D7).withValues(alpha: .86);
    canvas.drawArc(rect.deflate(width * .6), angle + 3.1, .12, false, spark);
    if (border['effect'] == 'double' || border['effect'] == 'rainbow') {
      final inner = rect.deflate(width * 2.2);
      canvas.drawArc(
        inner,
        -angle - 1.2,
        math.pi * .62,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * .45
          ..strokeCap = StrokeCap.round
          ..color = colors[1].withValues(alpha: .65),
      );
    }
    final particleAngle = -angle * .7 - .6;
    final at =
        center +
        Offset(math.cos(particleAngle), math.sin(particleAngle)) * radius;
    canvas.drawCircle(
      at,
      width * .6,
      Paint()
        ..color = colors[1].withValues(alpha: .23)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(at, width * .3, Paint()..color = const Color(0xFFFFEDCB));
  }

  @override
  bool shouldRepaint(_BorderPainter old) =>
      old.border != border || old.turn != turn;
}

class CreatorBadge extends StatelessWidget {
  const CreatorBadge({super.key, this.compact = false});
  final bool compact;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Créateur de Mordeviel, compte officiel',
    child: Tooltip(
      message: 'Créateur de Mordeviel · by Logan R.D',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 5 : 11,
          vertical: compact ? 2 : 5,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFD6AE70).withValues(alpha: .07),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: const Color(0xFFD6AE70).withValues(alpha: .35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified,
              size: compact ? 13 : 17,
              color: const Color(0xFFD6AE70),
            ),
            const SizedBox(width: 4),
            Text(
              compact ? 'Créateur' : 'CRÉATEUR',
              style: TextStyle(
                fontSize: compact ? 11 : 13,
                letterSpacing: compact ? 0 : 1.3,
                color: const Color(0xFFE5C18A),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
