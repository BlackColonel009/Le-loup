import 'dart:math' as math;
import 'package:flutter/material.dart';

class GuardianAura extends StatefulWidget {
  const GuardianAura({super.key, required this.intense});
  final bool intense;
  @override
  State<GuardianAura> createState() => _GuardianAuraState();
}

class _GuardianAuraState extends State<GuardianAura>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context)) {
      _motion.stop();
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Semantics(
      label: 'Protection du Salvateur',
      image: true,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _motion,
          builder: (context, _) =>
              CustomPaint(painter: _AuraPainter(_motion.value, widget.intense)),
        ),
      ),
    ),
  );
}

class _AuraPainter extends CustomPainter {
  const _AuraPainter(this.time, this.intense);
  final double time;
  final bool intense;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .44);
    final rect = Rect.fromCenter(
      center: center,
      width: size.width * .96,
      height: size.height * .84,
    );
    if (intense) {
      canvas.drawOval(
        rect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFDC75).withValues(alpha: .025),
              const Color(
                0xFFFFD467,
              ).withValues(alpha: .14 + .04 * math.sin(time * math.pi * 2)),
            ],
          ).createShader(rect),
      );
      for (final blur in [8.0, 0.0]) {
        canvas.drawOval(
          rect,
          Paint()
            ..color = const Color(
              0xFFFFD46B,
            ).withValues(alpha: blur > 0 ? .65 : .8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = blur > 0 ? 5 : 1.8
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
        );
      }
      for (var i = 0; i < 12; i++) {
        final angle = (time + i / 12) * math.pi * 2;
        final point =
            center +
            Offset(
              math.cos(angle) * rect.width / 2,
              math.sin(angle) * rect.height / 2,
            );
        canvas.drawCircle(
          point,
          i.isEven ? 2 : 1,
          Paint()..color = const Color(0xFFFFF1B8),
        );
      }
      canvas.drawArc(
        rect.deflate(6),
        -math.pi / 2,
        .6,
        false,
        Paint()
          ..color = const Color(0x99FFF3C3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    } else {
      for (var orb = 0; orb < 2; orb++) {
        for (var tail = 20; tail >= 0; tail--) {
          final angle = time * math.pi * 2 + orb * math.pi - tail * .025;
          final point =
              center +
              Offset(
                math.cos(angle) * rect.width / 2,
                math.sin(angle * 2 + orb * math.pi) * rect.height * .28,
              );
          final opacity = (1 - tail / 21) * .9;
          canvas.drawCircle(
            point,
            3 + (20 - tail) * .09,
            Paint()
              ..color = const Color(0xFFFFCE58).withValues(alpha: opacity)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
          );
          if (tail == 0) {
            canvas.drawCircle(
              point,
              2.5,
              Paint()..color = const Color(0xFFFFF4C9),
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AuraPainter old) =>
      old.time != time || old.intense != intense;
}
