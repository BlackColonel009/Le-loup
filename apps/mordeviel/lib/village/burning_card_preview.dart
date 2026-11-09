import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../cards/card_gallery.dart';
import '../cards/classic_role.dart';
import 'sulfuron_scene.dart';

class BurningCardPreview extends StatefulWidget {
  const BurningCardPreview({super.key});

  @override
  State<BurningCardPreview> createState() => _BurningCardPreviewState();
}

class _BurningCardPreviewState extends State<BurningCardPreview>
    with SingleTickerProviderStateMixin {
  late final _burn =
      AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 4300),
        )
        ..addStatusListener(_loopBurn)
        ..forward();

  void _loopBurn(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _burn.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _burn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF100D0A),
    appBar: AppBar(
      title: const Text('Aperçu · Combustion des cartes'),
      backgroundColor: const Color(0xFF100D0A),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final role = configuredRole('seer');
            final old = _panel(
              title: 'Ancien rendu',
              subtitle: 'Petites flammes arrondies.',
              buildCard: (progress) => _OldBottomBurnCard(
                progress: progress,
                child: RoleCardFront(
                  role: role,
                  ambience: CardAmbience.classic,
                ),
              ),
            );
            final gifBottom = _panel(
              title: 'Feu montant + GIF',
              subtitle: 'Le GIF fourni remplace les flammes du bord inférieur.',
              buildCard: (progress) => BottomUpGifBurningCard(
                progress: progress,
                child: RoleCardFront(
                  role: role,
                  ambience: CardAmbience.classic,
                ),
              ),
            );
            final proposal = _panel(
              title: 'Test réussi 1',
              subtitle:
                  'Le GIF accompagne la cavité qui s’étend depuis le centre.',
              buildCard: (progress) => BurningCard(
                progress: progress,
                child: RoleCardFront(
                  role: role,
                  ambience: CardAmbience.classic,
                ),
              ),
            );
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Comparaison de la combustion',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFFFC76B),
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Compare l’ancien rendu, le GIF sur le feu montant et la combustion centrale.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFD4C8B8)),
                ),
                const SizedBox(height: 24),
                if (constraints.maxWidth >= 740)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: old),
                      const SizedBox(width: 20),
                      Expanded(child: gifBottom),
                      const SizedBox(width: 20),
                      Expanded(child: proposal),
                    ],
                  )
                else
                  Column(
                    children: [
                      old,
                      const SizedBox(height: 20),
                      gifBottom,
                      const SizedBox(height: 20),
                      proposal,
                    ],
                  ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    _burn
                      ..reset()
                      ..forward();
                  },
                  icon: const Icon(Icons.replay),
                  label: const Text('Rejouer les deux animations'),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );

  Widget _panel({
    required String title,
    required String subtitle,
    required Widget Function(double progress) buildCard,
  }) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF1C1713),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF493322)),
    ),
    child: Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFFFD18B),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFD4C8B8), fontSize: 12),
        ),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: .7,
          child: AnimatedBuilder(
            animation: _burn,
            builder: (context, _) => buildCard(_burn.value),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _burn,
          builder: (context, _) => LinearProgressIndicator(
            value: _burn.value,
            color: const Color(0xFFFF8A24),
            backgroundColor: const Color(0xFF493322),
          ),
        ),
      ],
    ),
  );
}

double _oldEdge(double x, Size size, double progress) =>
    size.height * (1.08 - 1.2 * progress) +
    (math.sin(x * .083 + 2) * 8 +
            math.sin(x * .23) * 3 +
            math.sin(x * .041) * 12) *
        math.sin(math.pi * progress);

Path _oldFront(Size size, double progress, [double shift = 0]) {
  final path = Path()..moveTo(0, _oldEdge(0, size, progress) + shift);
  for (double x = 3; x < size.width + 3; x += 3) {
    path.lineTo(x, _oldEdge(x, size, progress) + shift);
  }
  return path;
}

class _OldBottomBurnCard extends StatelessWidget {
  const _OldBottomBurnCard({required this.progress, required this.child});
  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ClipPath(clipper: _OldBottomBurnClipper(progress), child: child),
      IgnorePointer(
        child: CustomPaint(painter: _OldBottomBurnPainter(progress)),
      ),
    ],
  );
}

class _OldBottomBurnClipper extends CustomClipper<Path> {
  const _OldBottomBurnClipper(this.progress);
  final double progress;

  @override
  Path getClip(Size size) => progress >= 1
      ? Path()
      : (_oldFront(size, progress)
          ..lineTo(size.width, 0)
          ..lineTo(0, 0)
          ..close());

  @override
  bool shouldReclip(_OldBottomBurnClipper old) => old.progress != progress;
}

class _OldBottomBurnPainter extends CustomPainter {
  const _OldBottomBurnPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= .03 || progress >= 1) return;
    final edge = _oldFront(size, progress);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(
      _oldFront(size, progress, -6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..color = const Color(0xFF20110B),
    );
    canvas.drawPath(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..color = const Color(0xFFFF5E08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawPath(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFFFD18B),
    );
    for (var i = 0; i < 42; i++) {
      final x = ((i * 73.91) % 100) / 100 * size.width;
      final phase = (progress * 3.4 + i * .173) % 1;
      final y = _oldEdge(x, size, progress) - phase * size.height * .32;
      final opacity = (1 - phase) * math.sin(math.pi * progress);
      canvas.drawCircle(
        Offset(x + math.sin(i + progress * 12) * 9, y),
        3 + phase * 13,
        Paint()
          ..color = Colors.grey.withValues(alpha: opacity * .12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawCircle(
        Offset(x + math.sin(i + progress * 12) * 9, y),
        1.2 + 1.6 * (1 - phase),
        Paint()
          ..color = Color.lerp(
            const Color(0xFFFFF4B5),
            const Color(0xFFF05B12),
            phase,
          )!.withValues(alpha: opacity),
      );
      if (i.isEven) {
        final base = _oldEdge(x, size, progress);
        final flame = Path()
          ..moveTo(x - 6, base + 5)
          ..quadraticBezierTo(
            x - 10,
            base - 12,
            x + math.sin(i + progress * 30) * 6,
            base - 18 - 22 * phase,
          )
          ..quadraticBezierTo(x + 12, base - 8, x + 6, base + 5)
          ..close();
        canvas.drawPath(
          flame,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Color(0xFFFFCC68),
                Color(0x99FF6810),
                Colors.transparent,
              ],
            ).createShader(Rect.fromLTWH(x - 12, base - 45, 24, 50)),
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OldBottomBurnPainter old) => old.progress != progress;
}
