import 'dart:math' as math;
import 'package:flutter/material.dart';

const _centerFireAsset = 'assets/village/fire-65.gif';

class BurningCard extends StatelessWidget {
  const BurningCard({super.key, required this.progress, required this.child});

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    final amount = math.pow(((p - .1) / .9).clamp(0.0, 1.0), 1.25).toDouble();
    final time = p * 7.2;
    return Semantics(
      label: 'La carte brûle du centre vers les bords',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final shredProgress = Curves.easeInCubic.transform(
            ((p - .76) / .24).clamp(0.0, 1.0),
          );
          final center = Offset(size.width / 2, size.height / 2);
          final shards = shredProgress == 0
              ? const <_Shard>[]
              : _makeShards(size);
          final leftRadius = math.max(
            _boundaryRadius(0, amount, time, size),
            _boundaryRadius(math.pi, amount, time, size),
          );
          final verticalRadius = math.max(
            _boundaryRadius(math.pi / 2, amount, time, size),
            _boundaryRadius(math.pi * 1.5, amount, time, size),
          );
          final holeWidth = leftRadius * 2;
          final holeHeight = verticalRadius * 2;
          const fireAspect = 400 / 600;
          final fireWidth = math.min(
            holeWidth * .78,
            holeHeight * fireAspect * .78,
          );
          final fireHeight = fireWidth / fireAspect;
          final fireOpacity = (1 - _ease((p - .965) / .035)).clamp(0.0, 1.0);

          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.none,
            children: [
              Opacity(
                opacity: 1 - shredProgress,
                child: ClipPath(
                  clipper: _CenterBurnClipper(amount, time),
                  child: child,
                ),
              ),
              if (p >= .06 && p < 1 && fireWidth > 0)
                Positioned(
                  left: center.dx - fireWidth / 2,
                  top:
                      center.dy -
                      verticalRadius +
                      holeHeight * .15 -
                      fireHeight,
                  width: fireWidth,
                  height: fireHeight,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: fireOpacity,
                      child: Image.asset(
                        _centerFireAsset,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                ),
              for (var index = 0; index < shards.length; index++)
                _FallingShard(
                  shard: shards[index],
                  index: index,
                  size: size,
                  center: center,
                  progress: p,
                  amount: amount,
                  time: time,
                  child: child,
                ),
              IgnorePointer(
                child: CustomPaint(
                  painter: _CenterBurnPainter(amount, p, time),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FallingShard extends StatelessWidget {
  const _FallingShard({
    required this.shard,
    required this.index,
    required this.size,
    required this.center,
    required this.progress,
    required this.amount,
    required this.time,
    required this.child,
  });

  final _Shard shard;
  final int index;
  final Size size;
  final Offset center;
  final double progress;
  final double amount;
  final double time;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final local = ((progress - .76) / .24).clamp(0.0, 1.0);
    final trigger = _hash(index + 61) * .28;
    final phase = _ease((local - trigger) / (1 - trigger));
    if (phase <= 0) return const SizedBox.shrink();

    final fall = (phase * .18 + phase * phase * .92) * size.height;
    final drift =
        math.sin(time * 7 + index * 1.7) * phase * size.width * .055 +
        (_hash(index + 191) - .5) * phase * size.width * .18;
    final spin = (_hash(index + 311) - .5) * phase * phase * 1.45;
    return Positioned.fill(
      child: Transform.translate(
        offset: center + Offset(drift, fall),
        child: Transform.rotate(
          angle: spin,
          child: Transform.translate(
            offset: -center,
            child: Opacity(
              opacity: 1 - phase,
              child: ClipPath(
                clipper: _ShardClipper(shard.points, amount, time),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Shard {
  const _Shard(this.points);
  final List<Offset> points;
}

List<_Shard> _makeShards(Size size) {
  const columns = 3;
  const rows = 4;
  final nodes = List.generate(
    rows + 1,
    (row) => List.generate(columns + 1, (column) {
      final edge = row == 0 || row == rows || column == 0 || column == columns;
      final index = row * (columns + 1) + column;
      return Offset(
        column / columns * size.width +
            (edge ? 0 : (_hash(index * 13 + 71) - .5) * size.width * .1),
        row / rows * size.height +
            (edge ? 0 : (_hash(index * 43 + 37) - .5) * size.height * .08),
      );
    }),
  );
  return [
    for (var row = 0; row < rows; row++)
      for (var column = 0; column < columns; column++)
        _Shard([
          nodes[row][column],
          nodes[row][column + 1],
          nodes[row + 1][column + 1],
          nodes[row + 1][column],
        ]),
  ];
}

class _CenterBurnClipper extends CustomClipper<Path> {
  const _CenterBurnClipper(this.amount, this.time);

  final double amount;
  final double time;

  @override
  Path getClip(Size size) => _remainingCardPath(size, amount, time);

  @override
  bool shouldReclip(_CenterBurnClipper old) =>
      old.amount != amount || old.time != time;
}

class _ShardClipper extends CustomClipper<Path> {
  const _ShardClipper(this.points, this.amount, this.time);

  final List<Offset> points;
  final double amount;
  final double time;

  @override
  Path getClip(Size size) {
    final shard = Path()..addPolygon(points, true);
    return Path.combine(
      PathOperation.intersect,
      shard,
      _remainingCardPath(size, amount, time),
    );
  }

  @override
  bool shouldReclip(_ShardClipper old) =>
      old.amount != amount || old.time != time || old.points != points;
}

Path _remainingCardPath(Size size, double amount, double time) {
  final card = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(size.shortestSide * .035),
      ),
    );
  if (amount <= 0) return card;
  if (amount >= 1) return Path();
  return Path.combine(
    PathOperation.difference,
    card,
    _burnPath(size, amount, time),
  );
}

Path _burnPath(Size size, double amount, double time) {
  final center = Offset(size.width / 2, size.height / 2);
  final path = Path();
  const steps = 240;
  for (var index = 0; index <= steps; index++) {
    final angle = index / steps * math.pi * 2;
    final radius = _boundaryRadius(angle, amount, time, size);
    final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    if (index == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  return path..close();
}

double _edgeDistance(double angle, Size size) {
  final dx = math.cos(angle);
  final dy = math.sin(angle);
  final tx = dx.abs() < 1e-5 ? double.infinity : size.width / 2 / dx.abs();
  final ty = dy.abs() < 1e-5 ? double.infinity : size.height / 2 / dy.abs();
  return math.min(tx, ty);
}

double _boundaryRadius(double angle, double amount, double time, Size size) {
  final edge = _edgeDistance(angle, size);
  final shortest = size.shortestSide;
  final circle = shortest * .47 * amount;
  final reach = _ease((amount - .58) / .4);
  final expanding = circle * (1 - reach) + edge * amount * reach;
  final roughness =
      math.sin(angle * 5 + .4) * .48 +
      math.sin(angle * 11 - 1.2) * .28 +
      math.sin(angle * 23 + 2.1) * .16 +
      math.sin(angle * 39 - .8) * .08;
  final flicker = math.sin(angle * 17 + time * 8) * shortest * .004;
  final jagged = math.min(
    shortest * .052,
    math.max(shortest * .008, edge * .13),
  );
  return math.max(
    0,
    expanding + roughness * jagged * math.sqrt(amount) + flicker,
  );
}

double _ease(double value) {
  final t = value.clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

double _hash(int value) {
  final raw = math.sin(value * 127.1 + 311.7) * 43758.5453;
  return raw - raw.floorToDouble();
}

class _CenterBurnPainter extends CustomPainter {
  const _CenterBurnPainter(this.amount, this.progress, this.time);

  final double amount;
  final double progress;
  final double time;

  @override
  void paint(Canvas canvas, Size size) {
    if (amount < .018 || progress >= 1) return;
    final path = _burnPath(size, amount, time);
    final opacity = math.max(.18, 1 - math.max(0, progress - .7) * 2.8);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * .026
        ..color = const Color(0xFF24140F).withValues(alpha: opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * .012
        ..color = const Color(0xFFFF5B0A).withValues(alpha: opacity * .72)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.shortestSide * .004
        ..color = const Color(0xFFFFB329).withValues(alpha: opacity * .72),
    );

    final center = Offset(size.width / 2, size.height / 2);
    for (var index = 0; index < 24; index++) {
      final age = (time * .62 + _hash(index + 8)) % 1;
      final angle = index * 37.17;
      final radius = _boundaryRadius(angle, amount, time, size);
      final point =
          center +
          Offset(math.cos(angle), math.sin(angle)) * radius +
          Offset(math.sin(age * 5 + index) * 5, age * size.height * .17);
      final alpha = (1 - age) * math.sin(math.pi * progress) * .72;
      canvas.drawCircle(
        point,
        size.shortestSide * (.004 + _hash(index + 72) * .005),
        Paint()
          ..color = Color.lerp(
            const Color(0xFF553522),
            const Color(0xFFE2762E),
            _hash(index + 94),
          )!.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_CenterBurnPainter old) =>
      old.amount != amount || old.progress != progress || old.time != time;
}
