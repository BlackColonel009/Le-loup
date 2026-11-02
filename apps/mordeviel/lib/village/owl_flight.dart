import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../content/content_image.dart';

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
      final perch = camera == null
          ? Offset(size.width - 50, 55)
          : MatrixUtils.transformPoint(
              camera!.value,
              Offset(world.width * .90, world.height * .16),
            );
      final perchedSize = camera == null
          ? 76.0
          : (120 * camera!.value.getMaxScaleOnAxis()).clamp(18.0, 90.0);
      if (seconds < 32 || seconds >= 41) {
        return Stack(
          children: [
            Positioned(
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
      final returning = seconds > 38;
      final t = ((seconds - (returning ? 38 : 32)) / (returning ? 3 : 6)).clamp(
        0.0,
        1.0,
      );
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
          Positioned(
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
