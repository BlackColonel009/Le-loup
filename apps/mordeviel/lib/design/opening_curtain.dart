import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The same damaged cloth moves with each panel, including its frayed edges.
/// Photographic textures are cached assets; no network or video decoder needed.
class OpeningCurtain extends StatelessWidget {
  const OpeningCurtain({super.key, required this.progress});
  final double progress;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      double stage(double a, double b) =>
          ((progress - a) / (b - a)).clamp(0, 1);
      final first = Curves.easeOutCubic.transform(stage(.10, .23));
      final second = Curves.easeOutCubic.transform(stage(.29, .42));
      final opening = Curves.easeInCubic.transform(stage(.44, .95));
      double shock(double start, double end) {
        final t = stage(start, end);
        return t >= 1 ? 0 : math.sin(t * math.pi * 5) * math.pow(1 - t, 2);
      }

      final tension = shock(.10, .27) + shock(.29, .46);
      final size = box.biggest;
      return ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            for (final left in [true, false])
              Transform(
                alignment: left ? Alignment.topLeft : Alignment.topRight,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, .0007)
                  ..translateByDouble(
                    (left ? -1 : 1) *
                        (opening * size.width * .56 +
                            tension * size.width * .004),
                    math.sin(opening * math.pi) * size.height * .025,
                    0,
                    1,
                  )
                  ..rotateZ((left ? -1 : 1) * opening * .045)
                  ..scaleByDouble(
                    1 - opening * .06,
                    1 + math.sin(opening * math.pi) * .025,
                    1,
                    1,
                  ),
                child: ClipPath(
                  clipper: _CurtainHalf(left),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/branding/opening/black_curtain.png',
                        fit: BoxFit.fill,
                        cacheWidth: 1280,
                        filterQuality: FilterQuality.medium,
                        excludeFromSemantics: true,
                      ),
                      ColoredBox(
                        color: Colors.black.withValues(
                          alpha: 1 - stage(.03, .10),
                        ),
                      ),
                      _slash(size, first, false),
                      _slash(size, second, true),
                      if (opening > 0)
                        CustomPaint(painter: _FrayedSeam(left, opening)),
                    ],
                  ),
                ),
              ),
            CustomPaint(painter: _ClothDust(progress)),
          ],
        ),
      );
    },
  );
  Widget _slash(Size size, double reveal, bool reverse) {
    if (reveal <= 0) return const SizedBox.shrink();
    return Positioned(
      left: size.width * .04,
      top: size.height * (reverse ? .26 : .10),
      width: size.width * .92,
      height: size.height * .62,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(reverse ? -1 : 1, 1, 1),
        child: ClipPath(
          clipper: _ScratchReveal(reveal),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/branding/opening/claw_tears.png',
                fit: BoxFit.fill,
                cacheWidth: 1280,
                filterQuality: FilterQuality.high,
                excludeFromSemantics: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Path curtainHalf(Size size, bool left) {
  final path = Path()..moveTo(left ? 0 : size.width, 0);
  for (var i = 0; i <= 72; i++) {
    final y = size.height * i / 72;
    final x =
        size.width *
        (.5 + .012 * math.sin(i * 1.73) + .006 * math.sin(i * 4.13));
    path.lineTo(x, y);
  }
  return path
    ..lineTo(left ? 0 : size.width, size.height)
    ..close();
}

class _CurtainHalf extends CustomClipper<Path> {
  const _CurtainHalf(this.left);
  final bool left;
  @override
  Path getClip(Size size) => curtainHalf(size, left);
  @override
  bool shouldReclip(_CurtainHalf old) => old.left != left;
}

class _ScratchReveal extends CustomClipper<Path> {
  const _ScratchReveal(this.reveal);
  final double reveal;
  @override
  Path getClip(Size s) {
    final p = Path()..moveTo(0, 0);
    if (reveal < .5) {
      p
        ..lineTo(s.width * reveal * 2, 0)
        ..lineTo(0, s.height * reveal * 2);
    } else {
      p
        ..lineTo(s.width, 0)
        ..lineTo(s.width, s.height * (reveal * 2 - 1))
        ..lineTo(s.width * (reveal * 2 - 1), s.height)
        ..lineTo(0, s.height);
    }
    return p..close();
  }

  @override
  bool shouldReclip(_ScratchReveal old) => old.reveal != reveal;
}

class _FrayedSeam extends CustomPainter {
  const _FrayedSeam(this.left, this.opening);
  final bool left;
  final double opening;
  @override
  void paint(Canvas canvas, Size size) {
    final sign = left ? -1.0 : 1.0;
    final edge = Paint()
      ..color = Color.lerp(
        const Color(0xFF151619),
        const Color(0xFF67666A),
        opening * .65,
      )!
      ..strokeWidth = 1.1;
    for (var i = 1; i < 72; i++) {
      final y = size.height * i / 72;
      final x =
          size.width *
          (.5 + .012 * math.sin(i * 1.73) + .006 * math.sin(i * 4.13));
      for (var f = 0; f < 3; f++) {
        final length = (3 + ((i * 13 + f * 7) % 9)) * opening;
        canvas.drawLine(
          Offset(x + sign * (1 + f), y + f * 1.8),
          Offset(x + sign * length, y + f * 1.8 + math.sin(i + f) * 5),
          edge,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FrayedSeam old) =>
      old.left != left || old.opening != opening;
}

class _ClothDust extends CustomPainter {
  const _ClothDust(this.progress);
  final double progress;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = (size.shortestSide / 390).clamp(.7, 2.0);
    final dust = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .4);
    final fiber = Paint()..strokeCap = StrokeCap.round;
    for (final reverse in [false, true]) {
      final random = math.Random(reverse ? 1907 : 604);
      for (var i = 0; i < 90; i++) {
        final path = random.nextDouble(), band = random.nextInt(3) - 1;
        final birth = (reverse ? .29 : .10) + path * .13;
        final age = (progress - birth) * 3.8;
        final x = .04 + .92 * (.13 + path * .7 + band * .065);
        final y =
            (reverse ? .26 : .10) + .62 * (.12 + path * .73 - band * .035);
        final vx = (random.nextDouble() - .5) * 96 * scale;
        final vy = (-25 - random.nextDouble() * 45) * scale;
        final radius = (.6 + random.nextDouble() * 1.4) * scale;
        final lifespan = .6 + random.nextDouble() * .85;
        final length = (2 + random.nextDouble() * 5) * scale;
        if (age < 0 || age > lifespan) continue;
        final alpha = (1 - age / lifespan) * .56;
        final at = Offset(
          (reverse ? 1 - x : x) * size.width + vx * age,
          y * size.height + vy * age + age * age * 76 * scale,
        );
        final shade = i % 4 == 0
            ? const Color(0xFF8E8C86)
            : const Color(0xFF55565B);
        if (i % 3 == 0) {
          fiber
            ..color = shade.withValues(alpha: alpha)
            ..strokeWidth = .65 * scale;
          final angle = i * 1.71 + age * 3;
          canvas.drawLine(
            at,
            at + Offset(math.cos(angle) * length, math.sin(angle) * length),
            fiber,
          );
        } else {
          canvas.drawCircle(
            at,
            radius,
            dust..color = shade.withValues(alpha: alpha),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_ClothDust old) => old.progress != progress;
}
