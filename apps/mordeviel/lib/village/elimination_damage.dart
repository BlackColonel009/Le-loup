import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Cosmetic damage follows the authoritative death cause, never the card's role.
/// The reveal owns the clock so successive deaths cannot leave effects running.
class EliminationDamage extends StatelessWidget {
  const EliminationDamage({
    super.key,
    required this.cause,
    required this.progress,
    required this.child,
  });
  final String cause;
  final double progress;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (cause != 'hunter' && cause != 'poison') return child;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final p = reduced ? 1.0 : progress.clamp(0.0, 1.0);
    return Semantics(
      label: cause == 'hunter'
          ? 'Trois impacts du Chasseur'
          : 'Carte rongée par le poison de la Sorcière',
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipPath(clipper: _DamageClipper(cause, p), child: child),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: cause == 'hunter'
                    ? BulletDamagePainter(p, reduced: reduced)
                    : PoisonDamagePainter(p, reduced: reduced),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const bulletPositions = [Offset(.29, .29), Offset(.69, .46), Offset(.40, .70)];
double _hit(double p, int i) => ((p - i * .28) / .15).clamp(0.0, 1.0);

Path _hole(Offset center, double radius, int seed) {
  final path = Path();
  for (var j = 0; j < 24; j++) {
    final angle = j * math.pi / 12;
    final r = radius * (1 + math.sin(j * 5.7 + seed * 1.9) * .17);
    final point = center + Offset(math.cos(angle), math.sin(angle)) * r;
    if (j == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  return path..close();
}

double _meltEdge(double x, Size s, double p) =>
    s.height * (1 - .25 * p) +
    (math.sin(x / s.width * math.pi * 7 + .8) +
            math.sin(x / s.width * math.pi * 13) * .3) *
        s.height *
        .025 *
        p;

Path _meltingCard(Size s, double p) {
  final path = Path()
    ..moveTo(0, 0)
    ..lineTo(s.width, 0);
  for (var i = 64; i >= 0; i--) {
    final x = s.width * i / 64;
    path.lineTo(x, _meltEdge(x, s, p));
  }
  return path..close();
}

class _DamageClipper extends CustomClipper<Path> {
  const _DamageClipper(this.cause, this.p);
  final String cause;
  final double p;
  @override
  Path getClip(Size size) {
    if (cause == 'poison') return _meltingCard(size, p);
    var path = Path()..addRect(Offset.zero & size);
    for (var i = 0; i < 3; i++) {
      final hit = _hit(p, i);
      if (hit > 0) {
        path = Path.combine(
          PathOperation.difference,
          path,
          _hole(
            Offset(
              bulletPositions[i].dx * size.width,
              bulletPositions[i].dy * size.height,
            ),
            size.width * .078 * Curves.easeOutCubic.transform(hit),
            i,
          ),
        );
      }
    }
    return path;
  }

  @override
  bool shouldReclip(covariant _DamageClipper old) =>
      old.p != p || old.cause != cause;
}

class BulletDamagePainter extends CustomPainter {
  const BulletDamagePainter(this.progress, {this.reduced = false});
  final double progress;
  final bool reduced;
  int get visibleImpacts =>
      List.generate(3, (i) => _hit(progress, i)).where((h) => h > 0).length;
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 3; i++) {
      final hit = _hit(progress, i);
      if (hit <= 0) continue;
      final center = Offset(
        bulletPositions[i].dx * size.width,
        bulletPositions[i].dy * size.height,
      );
      final r = size.width * .078 * Curves.easeOutCubic.transform(hit);
      // A burnt paper rim, exposed pale fibres and fine tears surround a real cutout.
      canvas.drawPath(
        _hole(center, r * 1.16, i),
        Paint()
          ..color = const Color(0xD5342117)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * .35
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
      canvas.drawPath(
        _hole(center, r * 1.08, i),
        Paint()
          ..color = const Color(0xFFAC9273)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * .006,
      );
      canvas.drawPath(
        _hole(center, r, i),
        Paint()
          ..color = const Color(0xFF241913)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * .009,
      );
      final tears = Paint()
        ..color = const Color(0xD5E9C894)
        ..strokeWidth = 1.1
        ..style = PaintingStyle.stroke;
      for (var j = 0; j < 8; j++) {
        final angle = j * math.pi / 4 + i;
        final ray = Offset(math.cos(angle), math.sin(angle));
        canvas.drawLine(
          center + ray * r * 1.1,
          center + ray * r * (1.4 + (j % 3) * .13),
          tears,
        );
        if (!reduced && hit < 1) {
          final debris = center + ray * (r * 1.5 + hit * size.width * .09);
          canvas.drawCircle(
            debris,
            (1 - hit) * 2.5,
            Paint()..color = Color.fromRGBO(229, 191, 128, (1 - hit) * .7),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant BulletDamagePainter old) =>
      old.progress != progress || old.reduced != reduced;
}

class PoisonDamagePainter extends CustomPainter {
  const PoisonDamagePainter(this.progress, {this.reduced = false});
  final double progress;
  final bool reduced;
  @override
  void paint(Canvas canvas, Size s) {
    final p = progress.clamp(0.0, 1.0);
    if (p == 0) return;
    canvas.save();
    canvas.clipPath(_meltingCard(s, p));
    final liquid = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.fromRGBO(122, 236, 34, .55 * p),
          Color.fromRGBO(37, 115, 14, .13 * p),
          Colors.transparent,
        ],
        stops: const [0, .72, 1],
      ).createShader(Offset.zero & s);
    canvas.drawRect(Offset.zero & s, liquid);
    // Viscous streams creep down the illustration without hiding the role label.
    for (var i = 0; i < 7; i++) {
      final x = s.width * (.07 + i * .145);
      final reach = s.height * (.10 + .43 * p) * (.65 + (i % 3) * .14);
      final width = s.width * (.008 + (i % 2) * .004);
      final path = Path()
        ..moveTo(x, 0)
        ..cubicTo(
          x - width * 3,
          reach * .4,
          x + width * 3,
          reach * .6,
          x,
          reach,
        );
      canvas.drawPath(
        path,
        Paint()
          ..color = Color.fromRGBO(128, 227, 38, .65 * p)
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * 2
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        Offset(x, reach),
        width * 1.5,
        Paint()..color = Color.fromRGBO(172, 255, 73, .65 * p),
      );
    }
    canvas.restore();
    final edge = Path();
    for (var i = 0; i <= 64; i++) {
      final x = s.width * i / 64;
      if (i == 0) {
        edge.moveTo(x, _meltEdge(x, s, p));
      } else {
        edge.lineTo(x, _meltEdge(x, s, p));
      }
    }
    canvas.drawPath(
      edge,
      Paint()
        ..color = Color.fromRGBO(155, 255, 55, .8 * p)
        ..style = PaintingStyle.stroke
        ..strokeWidth = s.width * .015
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      edge,
      Paint()
        ..color = Color.fromRGBO(200, 255, 115, .85 * p)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (var i = 0; i < 8; i++) {
      final x = s.width * (.08 + i * .12);
      final drift = reduced ? .45 : (p * 1.8 + i * .17) % 1;
      final base = _meltEdge(x, s, p);
      final y = base - drift * s.height * .72;
      final opacity = (math.sin(drift * math.pi).abs() * .23 * p).clamp(
        0.0,
        1.0,
      );
      final center = Offset(x + math.sin(i * 2 + drift * 6) * s.width * .05, y);
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: s.width * (.09 + drift * .15),
          height: s.height * (.06 + drift * .12),
        ),
        Paint()
          ..color = Color.fromRGBO(144, 242, 61, opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      // Drops separate from the dissolving lower edge.
      final dropY = base + ((p * 2 + i * .23) % 1) * s.height * .20;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, dropY),
          width: s.width * .012 * p,
          height: s.height * .028 * p,
        ),
        Paint()..color = Color.fromRGBO(135, 223, 33, .7 * p),
      );
    }
  }

  @override
  bool shouldRepaint(covariant PoisonDamagePainter old) =>
      old.progress != progress || old.reduced != reduced;
}
