import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../content/content_image.dart';

const owlFlightStart = 12.0, owlFlightReturn = 18.0, owlFlightEnd = 21.0;

Offset visibleOwlPerch(Size viewport, Offset projected) => Offset(
  projected.dx.clamp(48.0, math.max(48.0, viewport.width - 48)),
  projected.dy.clamp(100.0, math.max(100.0, viewport.height * .38)),
);

class OwlFlight extends StatelessWidget {
  const OwlFlight({
    super.key,
    required this.seconds,
    this.camera,
    required this.world,
  });
  final double seconds;
  final TransformationController? camera;
  final Size world;
  Offset _curve(Offset a, Offset b, Offset c, Offset d, double t) {
    final u = 1 - t;
    return a * (u * u * u) +
        b * (3 * u * u * t) +
        c * (3 * u * t * t) +
        d * (t * t * t);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final size = box.biggest;
      final projected = camera == null
          ? Offset(size.width - 50, 55)
          : MatrixUtils.transformPoint(
              camera!.value,
              Offset(world.width * .90, world.height * .16),
            );
      // Free camera navigation can put the old world anchor outside the screen.
      // Keep a branch at the visible edge instead of losing the owl entirely.
      final perch = visibleOwlPerch(size, projected);
      final edgeBranch = (perch - projected).distance > 1;
      final perchedSize = camera == null
          ? 76.0
          : (120 *
                    math.sqrt(
                      math.pow(camera!.value.entry(0, 0), 2) +
                          math.pow(camera!.value.entry(1, 0), 2),
                    ))
                .clamp(44.0, 90.0);
      if (seconds < owlFlightStart || seconds >= owlFlightEnd) {
        return Stack(
          children: [
            if (edgeBranch)
              Positioned.fill(child: CustomPaint(painter: _PerchBranch(perch))),
            Positioned(
              key: const ValueKey('owl-perched'),
              left: perch.dx - perchedSize / 2,
              top: perch.dy - perchedSize,
              width: perchedSize,
              height: perchedSize,
              child: const ContentImage(
                'assets/village/horror/owl_perched.png',
                fit: BoxFit.contain,
              ),
            ),
          ],
        );
      }
      final returning = seconds > owlFlightReturn;
      final t =
          ((seconds - (returning ? owlFlightReturn : owlFlightStart)) /
                  (returning ? 3 : 6))
              .clamp(0.0, 1.0);
      final center = size.center(Offset.zero);
      final a = returning
          ? Offset(-size.width * .15, size.height * .15)
          : perch;
      final d = returning ? perch : center;
      final b = returning
          ? Offset(size.width * .3, -50)
          : Offset(size.width * .55, size.height * .08);
      final c = returning
          ? Offset(size.width * .72, size.height * .12)
          : Offset(size.width * .18, size.height * .64);
      final p = _curve(a, b, c, d, t);
      final after = _curve(a, b, c, d, (t + .005).clamp(0.0, 1.0));
      final bank = ((after.dx - p.dx) / math.max(1, size.width) * 20).clamp(
        -.3,
        .3,
      );
      final depth = Curves.easeInExpo.transform(t);
      final extent = returning
          ? perchedSize +
                (1 - Curves.easeOutCubic.transform(t)) * size.shortestSide * .32
          : perchedSize + depth * size.longestSide * 2.4;
      final opacity = !returning && t > .91
          ? ((1 - t) / .09).clamp(0.0, 1.0)
          : 1.0;
      Widget bird = Stack(
        fit: StackFit.expand,
        children: [
          for (var wing = 0; wing < 3; wing++)
            ClipRect(
              clipper: _WingClip(wing),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, .001)
                  ..rotateY(
                    wing == 1
                        ? 0
                        : math.sin(seconds * 9) * .25 * (wing == 0 ? -1 : 1),
                  ),
                child: const ContentImage(
                  'assets/village/horror/owl.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
        ],
      );
      if (!returning && t > .78) {
        bird = ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: .6, sigmaY: .3),
          child: bird,
        );
      }
      return Stack(
        clipBehavior: Clip.none,
        children: [
          if (edgeBranch)
            Positioned.fill(child: CustomPaint(painter: _PerchBranch(perch))),
          Positioned(
            key: const ValueKey('owl-flying'),
            left:
                p.dx -
                extent / 2 +
                (!returning && t > .85 ? math.sin(seconds * 70) * 2 : 0),
            top: p.dy - extent / 2,
            width: extent,
            height: extent,
            child: Opacity(
              opacity: opacity,
              child: Transform.rotate(angle: bank, child: bird),
            ),
          ),
        ],
      );
    },
  );
}

class _PerchBranch extends CustomPainter {
  const _PerchBranch(this.perch);
  final Offset perch;
  @override
  void paint(Canvas canvas, Size size) {
    final right = perch.dx >= size.width / 2;
    final edge = right ? size.width : 0.0;
    final direction = right ? -1.0 : 1.0;
    final paint = Paint()
      ..color = const Color(0xFF22252A)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(
      Path()
        ..moveTo(edge, perch.dy + 30)
        ..quadraticBezierTo(
          perch.dx - direction * 35,
          perch.dy + 14,
          perch.dx + direction * 20,
          perch.dy - 2,
        ),
      paint..strokeWidth = 7,
    );
    canvas.drawPath(
      Path()
        ..moveTo(perch.dx - direction * 18, perch.dy + 9)
        ..lineTo(perch.dx + direction * 3, perch.dy - 14)
        ..moveTo(perch.dx - direction * 36, perch.dy + 18)
        ..lineTo(perch.dx - direction * 43, perch.dy - 5),
      paint..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_PerchBranch old) => old.perch != perch;
}

class _WingClip extends CustomClipper<Rect> {
  const _WingClip(this.part);
  final int part;
  @override
  Rect getClip(Size size) => Rect.fromLTRB(
    size.width * [0.0, .34, .66][part],
    0,
    size.width * [.34, .66, 1.0][part],
    size.height,
  );
  @override
  bool shouldReclip(covariant _WingClip old) => old.part != part;
}
