import 'dart:math' as math;
import 'package:flutter/material.dart';

const coinName = 'Lunes d’or';
const coinGold = Color(0xFFEAC76C);

String compactCoins(int amount) {
  if (amount < 1000) return '$amount';
  final unit = amount >= 999950 ? 1000000 : 1000;
  final number = (amount / unit).toStringAsFixed(amount % unit == 0 ? 0 : 1);
  return '${number.replaceFirst(RegExp(r'\.0$'), '').replaceAll('.', ',')}${unit == 1000 ? 'K' : 'M'}';
}

int coinsAtImpact(int amount, int milliseconds, List<int> impacts) {
  if (impacts.isEmpty) return 0;
  final hits = impacts.where((t) => t <= milliseconds).length;
  return amount * hits ~/ impacts.length;
}

class CoinToken extends StatelessWidget {
  const CoinToken({super.key, this.size = 28});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Pièce Lune d’or, tête de loup',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _CoinPainter()),
    ),
  );
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100);
    final paint = Paint();
    paint.color = Colors.black.withValues(alpha: .5);
    canvas.drawCircle(const Offset(51, 53), 46, paint);
    paint.shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFFFF0A7),
        Color(0xFFA97525),
        Color(0xFFE4BB5C),
        Color(0xFF6E451D),
      ],
    ).createShader(const Rect.fromLTWH(4, 4, 92, 92));
    canvas.drawCircle(const Offset(50, 50), 46, paint);
    paint.shader = null;
    paint
      ..color = const Color(0xFF634018)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(const Offset(50, 50), 39, paint);
    paint
      ..color = const Color(0xFFFFE7A1)
      ..strokeWidth = 1.2;
    canvas.drawCircle(const Offset(50, 50), 44, paint);
    for (var i = 0; i < 24; i++) {
      final a = i * math.pi / 12;
      canvas.drawLine(
        Offset(50 + 41 * math.cos(a), 50 + 41 * math.sin(a)),
        Offset(50 + 43 * math.cos(a), 50 + 43 * math.sin(a)),
        paint,
      );
    }
    final wolf = Path()
      ..moveTo(25, 23)
      ..lineTo(39, 32)
      ..lineTo(50, 29)
      ..lineTo(61, 32)
      ..lineTo(75, 23)
      ..lineTo(71, 58)
      ..lineTo(61, 73)
      ..lineTo(50, 83)
      ..lineTo(39, 73)
      ..lineTo(29, 58)
      ..close();
    paint
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF674318);
    canvas.drawPath(wolf, paint);
    canvas.save();
    canvas.translate(-1.3, -1.3);
    paint.color = const Color(0xFFF4D67D);
    canvas.drawPath(wolf, paint);
    canvas.restore();
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF6E491D);
    canvas.drawLine(const Offset(36, 46), const Offset(44, 51), paint);
    canvas.drawLine(const Offset(64, 46), const Offset(56, 51), paint);
    final muzzle = Path()
      ..moveTo(44, 63)
      ..lineTo(50, 68)
      ..lineTo(56, 63);
    canvas.drawPath(muzzle, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CoinPainter oldDelegate) => false;
}
