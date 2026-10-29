import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Fractal stepped leaders, fine branches, hot white core and a broad corona.
void drawLightning(
  Canvas canvas,
  Offset start,
  Offset end, {
  required int seed,
  double energy = 1,
  double width = 1.7,
  double travel = 1,
}) {
  if (energy <= 0) return;
  final random = math.Random(seed);
  var points = [start, end];
  final direction = end - start;
  final normal =
      Offset(-direction.dy, direction.dx) / math.max(1, direction.distance);
  var displacement = direction.distance * .19;
  for (var level = 0; level < 5; level++) {
    final next = <Offset>[points.first];
    for (var i = 1; i < points.length; i++) {
      next.add(
        (points[i - 1] + points[i]) / 2 +
            normal * ((random.nextDouble() - .5) * displacement),
      );
      next.add(points[i]);
    }
    points = next;
    displacement *= .52;
  }
  void stroke(List<Offset> vertices, double thickness, double strength) {
    final path = Path()..moveTo(vertices.first.dx, vertices.first.dy);
    for (final point in vertices.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    for (final layer in [
      (18.0, 9.0, .13),
      (7.0, 3.5, .34),
      (2.3, 1.0, .8),
      (1.0, 0.0, 1.0),
    ]) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..strokeWidth = thickness * layer.$1
          ..color = Color.fromRGBO(
            layer.$1 < 3 ? 244 : 91,
            layer.$1 < 3 ? 252 : 178,
            255,
            (strength * layer.$3).clamp(0.0, 1.0),
          )
          ..maskFilter = layer.$2 == 0
              ? null
              : MaskFilter.blur(BlurStyle.normal, layer.$2),
      );
    }
  }

  final visible = points
      .take(math.max(2, (points.length * travel.clamp(0, 1)).ceil()))
      .toList();
  stroke(visible, width, energy);
  if (direction.distance < 60) return;
  for (var i = 4; i < visible.length - 3; i += 5) {
    final branch = <Offset>[visible[i]];
    var point = visible[i];
    final sign = random.nextBool() ? 1.0 : -1.0;
    for (var j = 0; j < 5; j++) {
      point +=
          direction / 35 +
          normal * sign * (4 + random.nextDouble() * direction.distance * .04);
      branch.add(point);
    }
    stroke(branch, width * .45, energy * .7);
  }
}

class ElderLightning extends CustomPainter {
  const ElderLightning(this.progress, {this.reduced = false});
  final double progress;
  final bool reduced;
  @override
  void paint(Canvas canvas, Size size) {
    final t = ((progress - .3) / .7).clamp(0.0, 1.0);
    final energy = reduced
        ? .3
        : math.sin(t * math.pi) * (.7 + .3 * math.sin(t * 43).abs());
    if (energy <= 0) return;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.fromRGBO(112, 171, 255, energy * .26),
            Colors.transparent,
          ],
        ).createShader(Offset.zero & size),
    );
    for (var i = 0; i < 3; i++) {
      drawLightning(
        canvas,
        Offset(size.width * (.1 + i * .38), -12),
        Offset(size.width * (.75 - i * .25), size.height * 1.05),
        seed: 710 + i * 7 + (reduced ? 0 : (t * 28).floor()),
        energy: energy,
        width: 1.9,
        travel: reduced ? 1 : (t * 8).clamp(0.0, 1.0),
      );
    }
  }

  @override
  bool shouldRepaint(covariant ElderLightning old) =>
      old.progress != progress || old.reduced != reduced;
}
