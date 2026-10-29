import 'dart:math' as math;
import 'package:flutter/material.dart';

class MayorShatter extends StatelessWidget {
  const MayorShatter({
    super.key,
    required this.progress,
    required this.mayorCard,
    required this.child,
  });
  final double progress;
  final Widget mayorCard, child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (MediaQuery.disableAnimationsOf(context) || progress >= 1) {
        return child;
      }
      final random = math.Random(991);
      final vertices = <List<Offset>>[
        for (var y = 0; y <= 5; y++)
          [
            for (var x = 0; x <= 4; x++)
              Offset(
                x / 4 +
                    (x == 0 || x == 4 ? 0 : (random.nextDouble() - .5) * .12),
                y / 5 +
                    (y == 0 || y == 5 ? 0 : (random.nextDouble() - .5) * .12),
              ),
          ],
      ];
      final shards = <List<Offset>>[
        for (var y = 0; y < 5; y++)
          for (var x = 0; x < 4; x++) ...[
            [vertices[y][x], vertices[y][x + 1], vertices[y + 1][x]],
            [vertices[y][x + 1], vertices[y + 1][x + 1], vertices[y + 1][x]],
          ],
      ];
      final fall = ((progress - .23) / .77).clamp(0.0, 1.0);
      return Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          child,
          for (var i = 0; i < shards.length; i++)
            Builder(
              builder: (_) {
                final centroid = shards[i].reduce((a, b) => a + b) / 3;
                final delay = i % 7 * .012;
                final t = ((fall - delay) / (1 - delay)).clamp(0.0, 1.0);
                return Transform.translate(
                  offset: Offset(
                    (centroid.dx - .5) * box.maxWidth * t * .65,
                    box.maxHeight * (1.8 * t * t) - 25 * math.sin(t * math.pi),
                  ),
                  child: Transform(
                    alignment: Alignment(
                      centroid.dx * 2 - 1,
                      centroid.dy * 2 - 1,
                    ),
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, .001)
                      ..rotateZ((i.isEven ? 1 : -1) * t * (.35 + i % 5 * .15))
                      ..rotateY(t * (i % 3 - 1) * 1.1),
                    child: Opacity(
                      opacity: (1 - t * t).clamp(0.0, 1.0),
                      child: ClipPath(
                        clipper: _Shard(shards[i]),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ExcludeSemantics(child: mayorCard),
                            if (progress > .15)
                              CustomPaint(
                                painter: _GlassEdge(
                                  shards[i],
                                  (progress * 5).clamp(0.0, 1.0),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      );
    },
  );
}

class _Shard extends CustomClipper<Path> {
  _Shard(this.points);
  final List<Offset> points;
  @override
  Path getClip(Size size) => Path()
    ..addPolygon(
      points.map((p) => Offset(p.dx * size.width, p.dy * size.height)).toList(),
      true,
    );
  @override
  bool shouldReclip(covariant _Shard old) => false;
}

class _GlassEdge extends CustomPainter {
  _GlassEdge(this.points, this.opacity);
  final List<Offset> points;
  final double opacity;
  @override
  void paint(Canvas canvas, Size size) {
    final path = _Shard(points).getClip(size);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Color.fromRGBO(13, 23, 34, opacity * .9),
    );
    canvas.drawPath(
      path.shift(const Offset(.7, -.7)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .9
        ..color = Color.fromRGBO(224, 247, 255, opacity * .9),
    );
  }

  @override
  bool shouldRepaint(covariant _GlassEdge old) => old.opacity != opacity;
}
