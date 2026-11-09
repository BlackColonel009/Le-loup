import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../cards/card_gallery.dart';
import '../cards/classic_role.dart';

class RevivalAnimationPreview extends StatefulWidget {
  const RevivalAnimationPreview({super.key});

  @override
  State<RevivalAnimationPreview> createState() =>
      _RevivalAnimationPreviewState();
}

class _RevivalAnimationPreviewState extends State<RevivalAnimationPreview> {
  int _replay = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF13151A),
    appBar: AppBar(
      title: const Text('Aperçu · Régénération de la carte'),
      backgroundColor: const Color(0xFF13151A),
    ),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final role = configuredRole('seer');
            final ambience = CardAmbience.classic;
            final before = _previewPanel(
              title: 'Animation actuelle',
              subtitle: 'Rotation de la carte et rayons dorés.',
              child: _ExistingRevivalCardEffect(
                key: ValueKey('existing-$_replay'),
                role: role,
                ambience: ambience,
              ),
            );
            final proposal = _previewPanel(
              title: 'Nouvelle proposition',
              subtitle: 'Élévation, spirale et particules dorées.',
              child: _RevivalCardEffect(
                key: ValueKey('proposal-$_replay'),
                role: role,
                ambience: ambience,
              ),
            );
            final panels = constraints.maxWidth >= 760
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: before),
                      const SizedBox(width: 20),
                      Expanded(child: proposal),
                    ],
                  )
                : Column(
                    children: [before, const SizedBox(height: 20), proposal],
                  );
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                panels,
                const SizedBox(height: 16),
                const Text(
                  'La Sorcière vous a donné une chance.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFE7D9B6), fontSize: 17),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => setState(() => _replay++),
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

  Widget _previewPanel({
    required String title,
    required String subtitle,
    required Widget child,
  }) => Container(
    padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
    decoration: BoxDecoration(
      color: const Color(0xFF1B1E25),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF38343A)),
    ),
    child: Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFFF2D99A),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFFB7B0A3), fontSize: 12),
        ),
        const SizedBox(height: 6),
        SizedBox(width: 300, height: 410, child: RepaintBoundary(child: child)),
      ],
    ),
  );
}

class _ExistingRevivalCardEffect extends StatefulWidget {
  const _ExistingRevivalCardEffect({
    super.key,
    required this.role,
    required this.ambience,
  });
  final ClassicRole role;
  final CardAmbience ambience;

  @override
  State<_ExistingRevivalCardEffect> createState() =>
      _ExistingRevivalCardEffectState();
}

class _ExistingRevivalCardEffectState extends State<_ExistingRevivalCardEffect>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _motion.value = 1;
      } else {
        _motion.forward();
      }
    });
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    builder: (context, _) => Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _ExistingRevivalAura(_motion.value)),
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, .001)
            ..rotateY(math.sin(_motion.value * math.pi) * .38)
            ..rotateZ(
              (1 - Curves.easeOutCubic.transform(_motion.value)) * math.pi * 2,
            ),
          child: Center(
            child: Container(
              width: 216,
              height: 316,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFFFFCF68,
                    ).withValues(alpha: .18 * _motion.value),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: RoleCardFront(
                role: widget.role,
                ambience: widget.ambience,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ExistingRevivalAura extends CustomPainter {
  const _ExistingRevivalAura(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * 1.2,
        height: size.height * 1.1,
      ),
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x55FFF8C5), Color(0x66F7CD63), Color(0x00FFEA9E)],
        ).createShader(Offset.zero & size),
    );
    for (var i = 0; i < 26; i++) {
      final angle = (i / 26 + progress) * math.pi * 2;
      final start =
          center +
          Offset(
            math.cos(angle) * size.width * .5,
            math.sin(angle) * size.height * .45,
          );
      final end =
          center +
          Offset(
            math.cos(angle) * size.width * .7,
            math.sin(angle) * size.height * .58,
          );
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = const Color(0xBBFFF0A5)
          ..strokeWidth = i.isEven ? 2 : 1
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ExistingRevivalAura old) =>
      old.progress != progress;
}

class _RevivalCardEffect extends StatefulWidget {
  const _RevivalCardEffect({
    super.key,
    required this.role,
    required this.ambience,
  });
  final ClassicRole role;
  final CardAmbience ambience;

  @override
  State<_RevivalCardEffect> createState() => _RevivalCardEffectState();
}

class _RevivalCardEffectState extends State<_RevivalCardEffect>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _motion.value = 1;
      } else {
        _motion.forward();
      }
    });
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _motion,
    builder: (context, _) {
      final progress = _motion.value;
      final lift = Curves.easeOutBack.transform(
        ((progress - .08) / .64).clamp(0, 1),
      );
      final opacity = Curves.easeOut.transform(
        ((progress - .02) / .48).clamp(0, 1),
      );
      return Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _RevivalGlow(progress)),
          CustomPaint(painter: _RevivalSpiral(progress, foreground: false)),
          Center(
            child: Opacity(
              opacity: opacity,
              child: Transform.translate(
                offset: Offset(0, 70 * (1 - lift)),
                child: Transform.scale(
                  scale: .76 + .24 * lift,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, .0014)
                      ..rotateX(.12 * (1 - lift))
                      ..rotateY(.92 * (1 - lift))
                      ..rotateZ(.055 * (1 - lift)),
                    child: Container(
                      width: 200,
                      height: 286,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFFFCF68,
                            ).withValues(alpha: .12 + .3 * lift),
                            blurRadius: 16 + 28 * lift,
                            spreadRadius: 1 + 4 * lift,
                          ),
                          const BoxShadow(
                            color: Color(0x99000000),
                            blurRadius: 24,
                            offset: Offset(0, 14),
                          ),
                        ],
                      ),
                      child: RoleCardFront(
                        role: widget.role,
                        ambience: widget.ambience,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          CustomPaint(painter: _RevivalSpiral(progress, foreground: true)),
        ],
      );
    },
  );
}

class _RevivalGlow extends CustomPainter {
  const _RevivalGlow(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * .48);
    final strength = Curves.easeOut.transform(progress);
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.width * (.3 + .72 * strength),
        height: size.height * (.25 + .66 * strength),
      ),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.fromRGBO(255, 237, 177, .08 + .1 * strength),
            Color.fromRGBO(255, 190, 65, .04 + .08 * strength),
            const Color(0x00FFBA4A),
          ],
          stops: const [0, .48, 1],
        ).createShader(Offset.zero & size),
    );

    final ringCenter = Offset(size.width / 2, size.height * .81);
    for (final scale in [.68, .84, 1.0]) {
      final rect = Rect.fromCenter(
        center: ringCenter,
        width: size.width * scale,
        height: size.height * .12 * scale,
      );
      final paint = Paint()
        ..color = Color.fromRGBO(255, 218, 125, .12 + .28 * strength)
        ..style = PaintingStyle.stroke
        ..strokeWidth = scale == 1 ? 1.4 : 2.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawOval(rect, paint);
    }

    for (var i = 0; i < 24; i++) {
      final seed = i * .61803398875;
      final t = (seed + progress * (.38 + (i % 4) * .06)) % 1;
      final x = size.width * (.12 + .76 * ((seed * 3.7) % 1));
      final y = size.height * (.88 - .72 * t);
      final radius = 1.1 + (i % 3) * .55;
      final alpha = (.2 + .65 * math.sin(math.pi * t)).clamp(0, 1).toDouble();
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = Color.fromRGBO(255, 226, 151, alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RevivalGlow old) => old.progress != progress;
}

class _RevivalSpiral extends CustomPainter {
  const _RevivalSpiral(this.progress, {required this.foreground});
  final double progress;
  final bool foreground;

  @override
  void paint(Canvas canvas, Size size) {
    final visible = Curves.easeOutCubic.transform(progress);
    if (visible <= 0) return;
    const steps = 112;
    final centerX = size.width / 2;
    final path = Path();
    for (var i = 0; i < steps; i++) {
      final t0 = visible * i / steps;
      final t1 = visible * (i + 1) / steps;
      final angle0 = t0 * math.pi * 5 + progress * math.pi * 1.4;
      final angle1 = t1 * math.pi * 5 + progress * math.pi * 1.4;
      final depth = math.cos((angle0 + angle1) / 2);
      if ((depth >= 0) != foreground) continue;

      final p0 = _point(size, centerX, t0, angle0);
      final p1 = _point(size, centerX, t1, angle1);
      path
        ..moveTo(p0.dx, p0.dy)
        ..lineTo(p1.dx, p1.dy);
    }
    final phase = Curves.easeOut.transform(progress);
    final opacity = .3 + .62 * phase;
    canvas.drawPath(
      path,
      Paint()
        ..color = Color.fromRGBO(255, 190, 55, opacity * .42)
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Color.fromRGBO(255, 203, 91, opacity * .8)
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Color.fromRGBO(255, 246, 202, opacity)
        ..strokeWidth = 1.15
        ..strokeCap = StrokeCap.round,
    );
  }

  Offset _point(Size size, double centerX, double t, double angle) => Offset(
    centerX + math.sin(angle) * size.width * .39,
    size.height * (.78 - .58 * t) + math.cos(angle) * size.height * .09,
  );

  @override
  bool shouldRepaint(covariant _RevivalSpiral old) =>
      old.progress != progress || old.foreground != foreground;
}
