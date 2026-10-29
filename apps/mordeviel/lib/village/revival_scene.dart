import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../cards/card_gallery.dart';
import '../cards/classic_role.dart';
import '../content/downloads_screen.dart';
import '../content/pack_store.dart';

const revivalText =
    'La Sorcière vous a donné une chance. À vous de choisir votre destin.';
Future<void> showRevival(
  BuildContext context, {
  required String role,
  required CardAmbience ambience,
  bool feminine = false,
  String? rescuer,
  required VoidCallback onReveal,
  required VoidCallback onClose,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => _Revival(
    role: role,
    ambience: ambience,
    feminine: feminine,
    rescuer: rescuer,
    onReveal: onReveal,
  ),
).whenComplete(onClose);

class _Revival extends StatefulWidget {
  const _Revival({
    required this.role,
    required this.ambience,
    required this.feminine,
    this.rescuer,
    required this.onReveal,
  });
  final String role;
  final CardAmbience ambience;
  final bool feminine;
  final String? rescuer;
  final VoidCallback onReveal;
  @override
  State<_Revival> createState() => _RevivalState();
}

class _RevivalState extends State<_Revival>
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
      widget.onReveal();
      if (!MediaQuery.disableAnimationsOf(context)) {
        _motion.forward();
      } else {
        _motion.value = 1;
      }
    });
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Une seconde chance',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 240,
              height: 340,
              child: AnimatedBuilder(
                animation: _motion,
                builder: (context, _) => Stack(
                  clipBehavior: Clip.none,
                  fit: StackFit.expand,
                  children: [
                    CustomPaint(painter: _RevivalAura(_motion.value)),
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, .001)
                        ..rotateY(math.sin(_motion.value * math.pi) * .38)
                        ..rotateZ(
                          (1 - Curves.easeOutCubic.transform(_motion.value)) *
                              math.pi *
                              2,
                        ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: RoleCardFront(
                          role: configuredRole(
                            widget.role,
                            feminine: widget.feminine,
                            edition: widget.ambience.asset,
                          ),
                          ambience: widget.ambience,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(revivalText, textAlign: TextAlign.center),
            TextButton.icon(
              onPressed: () async {
                if (PackStore.instance.pathFor(
                      'assets/audio/classic/neural/old_witch/revival.wav',
                    ) ==
                    null) {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DownloadsScreen(
                        requiredPackIds: {'voice-old-witch'},
                      ),
                    ),
                  );
                }
                if (mounted) widget.onReveal();
              },
              icon: const Icon(Icons.record_voice_over),
              label: const Text(
                'Écouter la Sorcière · Télécharger la voix si nécessaire',
              ),
            ),
            if (widget.rescuer != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'La Sorcière qui t’a sauvé : ${widget.rescuer}',
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Choisir mon destin'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RevivalAura extends CustomPainter {
  const _RevivalAura(this.p);
  final double p;
  @override
  void paint(Canvas canvas, Size s) {
    final center = s.center(Offset.zero);
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: s.width * 1.2,
        height: s.height * 1.1,
      ),
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0x55FFF8C5), Color(0x66F7CD63), Color(0x00FFEA9E)],
        ).createShader(Offset.zero & s),
    );
    for (var i = 0; i < 26; i++) {
      final a = (i / 26 + p) * math.pi * 2;
      final start =
          center +
          Offset(math.cos(a) * s.width * .5, math.sin(a) * s.height * .45);
      final end =
          center +
          Offset(math.cos(a) * s.width * .7, math.sin(a) * s.height * .58);
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = const Color(0xBBFFF0A5)
          ..strokeWidth = (i.isEven ? 2 : 1)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RevivalAura old) => old.p != p;
}
