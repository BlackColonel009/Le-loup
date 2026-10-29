import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Lens splashes stay on the screen, while fine airborne droplets fall behind.
class BloodSplatterPainter extends CustomPainter {
  const BloodSplatterPainter(
    this.progress, {
    required this.seed,
    this.reduced = false,
  });
  final double progress;
  final int seed;
  final bool reduced;
  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final random = math.Random(seed);
    final burst = reduced
        ? 1.0
        : Curves.easeOutExpo.transform((progress * 3).clamp(0.0, 1.0));
    final center = size.center(Offset.zero);
    for (var i = 0; i < 115; i++) {
      final angle = random.nextDouble() * math.pi * 2;
      final nearLens = i < 18;
      final destination = Offset(
        math.cos(angle) * size.width * (.27 + random.nextDouble() * .48),
        math.sin(angle) * size.height * (.23 + random.nextDouble() * .37),
      );
      final point =
          center +
          destination * burst +
          Offset(0, nearLens ? 0 : progress * progress * 70);
      final radius = nearLens
          ? 10 + random.nextDouble() * 27
          : 1.2 + random.nextDouble() * 5;
      final opacity = (nearLens ? .86 : .65) * (progress * 12).clamp(0.0, 1.0);
      final shape = Path();
      final outline = <Offset>[];
      for (var j = 0; j < 16; j++) {
        final theta = j * math.pi / 8;
        final r = radius * (.7 + random.nextDouble() * .6);
        final q = point + Offset(math.cos(theta) * r, math.sin(theta) * r * .8);
        outline.add(q);
      }
      shape.moveTo(outline.first.dx, outline.first.dy);
      for (var j = 0; j < outline.length; j++) {
        final previous = outline[(j + 15) % 16], current = outline[j];
        final next = outline[(j + 1) % 16], after = outline[(j + 2) % 16];
        final a = current + (next - previous) / 6,
            b = next - (after - current) / 6;
        shape.cubicTo(a.dx, a.dy, b.dx, b.dy, next.dx, next.dy);
      }
      shape.close();
      canvas.drawPath(
        shape,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-.3, -.4),
            colors: [
              Color.fromRGBO(53, 0, 6, opacity),
              Color.fromRGBO(141, 4, 17, opacity),
            ],
          ).createShader(Rect.fromCircle(center: point, radius: radius)),
      );
      if (nearLens) {
        // Wet specular fleck and a viscous run down the viewing glass.
        canvas.drawOval(
          Rect.fromCenter(
            center: point - Offset(radius * .3, radius * .35),
            width: radius * .36,
            height: radius * .045,
          ),
          Paint()
            ..color = Color.fromRGBO(255, 208, 208, opacity * .3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .6),
        );
        final run =
            (reduced ? .12 : math.max(0, progress - .28)) * radius * 3.5;
        final stream = Path()
          ..moveTo(point.dx - radius * .10, point.dy)
          ..cubicTo(
            point.dx - radius * .07,
            point.dy + radius,
            point.dx + radius * .03,
            point.dy + run,
            point.dx - radius * .02,
            point.dy + radius * .4 + run,
          )
          ..quadraticBezierTo(
            point.dx + radius * .10,
            point.dy + radius * .55 + run,
            point.dx + radius * .09,
            point.dy + radius * .35 + run,
          )
          ..cubicTo(
            point.dx + radius * .04,
            point.dy + run * .6,
            point.dx + radius * .13,
            point.dy + radius,
            point.dx + radius * .10,
            point.dy,
          )
          ..close();
        canvas.drawPath(
          stream,
          Paint()..color = Color.fromRGBO(107, 0, 12, opacity * .9),
        );
        for (var drop = 0; drop < 8; drop++) {
          final a = random.nextDouble() * math.pi * 2;
          final d = radius * (1.1 + random.nextDouble() * .8);
          canvas.drawOval(
            Rect.fromCenter(
              center: point + Offset(math.cos(a) * d, math.sin(a) * d),
              width: 1 + random.nextDouble() * 3,
              height: 1 + random.nextDouble() * 5,
            ),
            Paint()..color = Color.fromRGBO(153, 4, 19, opacity * .8),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant BloodSplatterPainter old) =>
      progress != old.progress || seed != old.seed;
}
