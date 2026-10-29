import 'dart:math' as math;
import 'package:flutter/material.dart';

class SentenceSeparation extends StatelessWidget {
  const SentenceSeparation({
    super.key,
    required this.progress,
    required this.edition,
    required this.seed,
    required this.child,
  });
  final double progress;
  final String edition;
  final int seed;
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final reduced = MediaQuery.disableAnimationsOf(context);
      final p = reduced
          ? 1.0
          : Curves.easeOutCubic.transform(progress.clamp(0.0, 1.0));
      final vertical = seed % 3 != 1, horizontal = seed % 3 != 0;
      final pieces = <Rect>[
        for (var y = 0; y < (horizontal ? 2 : 1); y++)
          for (var x = 0; x < (vertical ? 2 : 1); x++)
            Rect.fromLTWH(
              x / (vertical ? 2 : 1),
              y / (horizontal ? 2 : 1),
              1 / (vertical ? 2 : 1),
              1 / (horizontal ? 2 : 1),
            ),
      ];
      return Semantics(
        label: 'Carte séparée après le vote du village',
        child: Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            for (final piece in pieces)
              Transform.translate(
                offset: Offset(
                  vertical
                      ? (piece.center.dx - .5) * box.maxWidth * .18 * p
                      : 0,
                  horizontal
                      ? (piece.center.dy - .5) * box.maxHeight * .12 * p
                      : 0,
                ),
                child: Transform.rotate(
                  angle: reduced ? 0 : (piece.center.dx - .5) * .06 * p,
                  child: ClipRect(
                    clipper: _Piece(piece),
                    child: ExcludeSemantics(child: child),
                  ),
                ),
              ),
            if (edition == 'horror' || edition == 'intense')
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _SentenceEffects(
                      p,
                      edition,
                      seed,
                      vertical,
                      horizontal,
                      reduced,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

class _Piece extends CustomClipper<Rect> {
  const _Piece(this.piece);
  final Rect piece;
  @override
  Rect getClip(Size size) => Rect.fromLTWH(
    piece.left * size.width,
    piece.top * size.height,
    piece.width * size.width,
    piece.height * size.height,
  );
  @override
  bool shouldReclip(covariant _Piece old) => old.piece != piece;
}

class _SentenceEffects extends CustomPainter {
  const _SentenceEffects(
    this.p,
    this.edition,
    this.seed,
    this.vertical,
    this.horizontal,
    this.reduced,
  );
  final double p;
  final String edition;
  final int seed;
  final bool vertical, horizontal, reduced;
  @override
  void paint(Canvas canvas, Size size) {
    if (p <= 0) return;
    final center = size.center(Offset.zero);
    if (edition == 'horror') {
      final random = math.Random(seed);
      for (var i = 0; i < 28; i++) {
        final angle = random.nextDouble() * math.pi * 2;
        final distance = (.15 + random.nextDouble() * .8) * size.width * p;
        final point =
            center +
            Offset(
              math.cos(angle) * distance,
              math.sin(angle) * distance * 1.3,
            );
        final radius = (2 + random.nextDouble() * 8) * (.4 + .6 * p);
        final paint = Paint()
          ..color = Color(i.isEven ? 0xCC8B0D21 : 0xBBD92332);
        if (i % 5 == 0) {
          paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        }
        canvas.drawOval(
          Rect.fromCenter(
            center: point,
            width: radius,
            height: radius * (1.2 + p * .7),
          ),
          paint,
        );
        if (i % 3 == 0) {
          canvas.drawLine(
            point,
            point +
                Offset(
                  -math.cos(angle) * radius * 2,
                  -math.sin(angle) * radius * 2,
                ),
            paint..strokeWidth = radius * .3,
          );
        }
      }
    } else {
      for (final axis in [if (vertical) true, if (horizontal) false]) {
        final path = Path();
        for (var i = 0; i <= 28; i++) {
          final along = i / 28;
          final jitter = reduced
              ? 0
              : math.sin(i * 7.3 + p * 47 + seed) * size.width * .025 * p;
          final point = axis
              ? Offset(size.width * .5 + jitter, size.height * along)
              : Offset(size.width * along, size.height * .5 + jitter);
          if (i == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 8
            ..color = const Color(0x993DBDFB)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
        );
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..color = const Color(0xFFDAF9FF),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SentenceEffects old) =>
      old.p != p || old.edition != edition;
}
