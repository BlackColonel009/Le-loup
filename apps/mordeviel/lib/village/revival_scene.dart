import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../cards/card_gallery.dart';
import '../cards/classic_role.dart';
import '../content/downloads_screen.dart';
import '../content/pack_store.dart';

const revivalText =
    'La Sorcière vous a donné une chance. À vous de choisir votre destin.';
const _faceRevealProgress = .40;
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );
  bool _concealed = false;
  bool _announced = false;

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _concealed = lifecycle != null && lifecycle != AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_concealed) _reveal();
    });
  }

  void _reveal() {
    if (!_announced) {
      _announced = true;
      widget.onReveal();
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.value = 1;
    } else if (!_motion.isCompleted) {
      _motion.forward();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed || _concealed) return;
    _motion.stop();
    setState(() => _concealed = true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _concealed
      ? AlertDialog(
          title: const Text('Carte masquée'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Choisir mon destin'),
            ),
            FilledButton(
              onPressed: () {
                setState(() => _concealed = false);
                _reveal();
              },
              child: const Text('Afficher la carte'),
            ),
          ],
        )
      : Dialog(
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
                      builder: (context, _) {
                        final progress = _motion.value;
                        const turnStart = .08;
                        final turn = Curves.easeInOut.transform(
                          ((progress - turnStart) /
                                  (2 * (_faceRevealProgress - turnStart)))
                              .clamp(0.0, 1.0),
                        );
                        final faceUp = progress >= _faceRevealProgress;
                        final lift = Curves.easeOutCubic.transform(progress);
                        final opacity = Curves.easeOut
                            .transform(((progress - .02) / .48).clamp(0, 1))
                            .clamp(0, 1)
                            .toDouble();
                        return Stack(
                          clipBehavior: Clip.none,
                          fit: StackFit.expand,
                          children: [
                            CustomPaint(painter: _RevivalGlow(progress)),
                            CustomPaint(
                              painter: _RevivalSpiral(
                                progress,
                                foreground: false,
                              ),
                            ),
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
                                        ..rotateY(
                                          math.pi * (faceUp ? 1 - turn : -turn),
                                        )
                                        ..rotateZ(.055 * (1 - lift)),
                                      child: Container(
                                        width: 200,
                                        height: 286,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFFFCF68)
                                                  .withValues(
                                                    alpha: .12 + .3 * lift,
                                                  ),
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
                                        child: faceUp
                                            ? RoleCardFront(
                                                role: configuredRole(
                                                  widget.role,
                                                  feminine: widget.feminine,
                                                  edition:
                                                      widget.ambience.asset,
                                                ),
                                                ambience: widget.ambience,
                                              )
                                            : Image.asset(
                                                'assets/village/card_back.png',
                                                fit: BoxFit.contain,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            CustomPaint(
                              painter: _RevivalSpiral(
                                progress,
                                foreground: true,
                              ),
                            ),
                          ],
                        );
                      },
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
                      if (mounted && !_concealed) widget.onReveal();
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
    const steps = 96;
    final centerX = size.width / 2;
    final path = Path();
    for (final offset in [0.0, math.pi]) {
      var connected = false;
      for (var i = 0; i <= steps; i++) {
        final t = visible * i / steps;
        final angle = offset + t * math.pi * 3.8 - progress * math.pi * 1.7;
        if ((math.cos(angle) >= 0) != foreground) {
          connected = false;
          continue;
        }
        final point = _point(size, centerX, t, angle);
        if (connected) {
          path.lineTo(point.dx, point.dy);
        } else {
          path.moveTo(point.dx, point.dy);
          connected = true;
        }
      }
    }
    final phase = Curves.easeOut.transform(progress);
    final opacity =
        (.18 + .75 * phase) *
        (1 - Curves.easeIn.transform(((progress - .79) / .21).clamp(0.0, 1.0)));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Color.fromRGBO(255, 190, 55, opacity * .42)
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Color.fromRGBO(255, 203, 91, opacity * .8)
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Color.fromRGBO(255, 246, 202, opacity)
        ..strokeWidth = 1.15
        ..strokeCap = StrokeCap.round,
    );
    if (!foreground) return;
    final pulse = ((progress - _faceRevealProgress) / .24).clamp(0.0, 1.0);
    if (progress < _faceRevealProgress || pulse >= 1) return;
    final light = Rect.fromCircle(
      center: Offset(centerX, size.height * .47),
      radius: size.width * (.22 + pulse * .66),
    );
    canvas.drawOval(
      light,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFEBB0).withValues(alpha: .46 * (1 - pulse)),
            const Color(0x00FFBB58),
          ],
        ).createShader(light),
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
