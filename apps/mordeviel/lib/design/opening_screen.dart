import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_theme.dart';

/// Une ouverture finie, sans pourcentage fictif : l'accueil attend aussi [ready].
class OpeningScreen extends StatefulWidget {
  const OpeningScreen({
    super.key,
    this.ready,
    required this.onStart,
    required this.onScratch,
    required this.onComplete,
  });
  final Future<void>? ready;
  final VoidCallback onStart, onComplete;
  final ValueChanged<int> onScratch;
  @override
  State<OpeningScreen> createState() => _OpeningScreenState();
}

class _OpeningScreenState extends State<OpeningScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _time;
  bool _ready = false, _started = false, _finished = false;
  bool _reduced = false, _paused = false, _skip = false;
  final _struck = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _time =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 3800),
          )
          ..addListener(_tick)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) _finish();
          });
    if (widget.ready == null) {
      _ready = true;
    } else {
      unawaited(_waitForReady());
    }
  }

  Future<void> _waitForReady() async {
    // Une erreur audio ne doit pas bloquer l'accès au jeu.
    try {
      await widget.ready;
    } catch (_) {
      /* Le jeu reste accessible. */
    }
    if (!mounted) return;
    _ready = true;
    _begin();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (_reduced) _time.duration = const Duration(milliseconds: 450);
    _begin();
  }

  void _begin() {
    if (!_ready || _started || !mounted || _paused) return;
    // Les callbacks et changements de page restent en dehors de build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _started || _paused) return;
      _started = true;
      widget.onStart();
      if (_skip) {
        _finish();
      } else {
        _time.forward();
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _tick() {
    if (_reduced || _finished) return;
    for (final (strike, threshold) in [(1, .1), (2, .29)]) {
      if (_time.value >= threshold && _struck.add(strike)) {
        widget.onScratch(strike);
      }
    }
  }

  void _finish() {
    if (_finished || !_ready) return;
    _finished = true;
    _time.stop();
    widget.onComplete();
  }

  void _skipOpening() {
    _skip = true;
    _time.stop();
    if (_ready) _finish();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
    if (_paused) {
      _time.stop();
    } else if (_started && !_finished && !_skip) {
      _time.forward();
    } else {
      _begin();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: GameTheme.ink,
    body: AnimatedBuilder(
      animation: _time,
      builder: (context, _) {
        final t = _time.value;
        double stage(double a, double b) => ((t - a) / (b - a)).clamp(0, 1);
        final open = _reduced
            ? 1.0
            : Curves.easeInOutCubic.transform(stage(.38, .68));
        final sweep = _reduced ? 0.0 : stage(.56, .9);
        return Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0xFF29342D), GameTheme.ink],
                  radius: .8,
                ),
              ),
            ),
            Center(
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Semantics(
                          label: 'Logo de Mordeviel Legendary',
                          image: true,
                          child: ExcludeSemantics(
                            child: Container(
                              constraints: const BoxConstraints(
                                maxWidth: 330,
                                maxHeight: 330,
                              ),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: GameTheme.gold.withValues(
                                      alpha: _reduced
                                          ? .07
                                          : .06 + .04 * math.sin(t * math.pi),
                                    ),
                                    blurRadius: 70,
                                    spreadRadius: 10,
                                  ),
                                ],
                              ),
                              child: ShaderMask(
                                blendMode: BlendMode.srcATop,
                                shaderCallback: (bounds) =>
                                    LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        const Color(0xDFFFF4D9),
                                        Colors.transparent,
                                      ],
                                      stops: const [0, .5, 1],
                                    ).createShader(
                                      Rect.fromLTWH(
                                        bounds.width * (-.8 + sweep * 2),
                                        0,
                                        bounds.width * .65,
                                        bounds.height,
                                      ),
                                    ),
                                child: Image.asset(
                                  'assets/branding/logo.png',
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Le village s’éveille…',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: GameTheme.ivory,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Semantics(
                        label: 'Ouverture du village',
                        child: SizedBox(
                          width: 110,
                          height: 2,
                          child: LinearProgressIndicator(
                            value: t,
                            color: GameTheme.gold,
                            backgroundColor: GameTheme.gold.withValues(
                              alpha: .15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!_reduced)
              IgnorePointer(
                child: CustomPaint(
                  painter: _TornCoverPainter(
                    first: stage(.1, .23),
                    second: stage(.29, .46),
                    opening: open,
                  ),
                ),
              ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton(
                    onPressed: _skipOpening,
                    child: const Text('Passer'),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class _TornCoverPainter extends CustomPainter {
  const _TornCoverPainter({
    required this.first,
    required this.second,
    required this.opening,
  });
  final double first, second, opening;

  Path _half(Size size, bool left) {
    final path = Path()..moveTo(left ? 0 : size.width, 0);
    for (var i = 0; i <= 28; i++) {
      final y = size.height * i / 28;
      final x =
          size.width *
          (.5 + .035 * math.sin(i * 2.3) + .018 * math.sin(i * 5.1));
      path.lineTo(x, y);
    }
    path.lineTo(left ? 0 : size.width, size.height);
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (opening == 1) return;
    for (final left in [true, false]) {
      final path = _half(size, left);
      canvas.save();
      canvas.translate((left ? -1 : 1) * opening * (size.width * .7), 0);
      if (opening > 0) {
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFF060A0E)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
        );
      }
      canvas.save();
      canvas.clipPath(path);
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF172127), Color(0xFF080D12), Color(0xFF202521)],
          ).createShader(Offset.zero & size),
      );
      // Grain et fibres fixes : aucun bruit visuel aléatoire entre deux frames.
      final grain = Paint()
        ..color = GameTheme.gold.withValues(alpha: .045)
        ..strokeWidth = .7;
      for (var i = 0; i < 70; i++) {
        final y = i * size.height / 70;
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y + math.sin(i) * 12),
          grain,
        );
      }
      _scratch(canvas, size, first, false);
      _scratch(canvas, size, second, true);
      canvas.restore();
      if (opening > 0) {
        canvas.drawPath(
          path,
          Paint()
            ..color = GameTheme.gold.withValues(alpha: .3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
      canvas.restore();
    }
  }

  void _scratch(Canvas canvas, Size size, double progress, bool reverse) {
    if (progress == 0) return;
    final start = Offset(
      size.width * (reverse ? .86 : .14),
      size.height * (reverse ? .31 : .24),
    );
    final end = Offset(
      size.width * (reverse ? .16 : .86),
      size.height * (reverse ? .76 : .58),
    );
    final direction = end - start;
    final normal = Offset(-direction.dy, direction.dx) / direction.distance;
    for (var claw = -1; claw <= 1; claw++) {
      final path = Path()
        ..moveTo(
          start.dx + normal.dx * claw * 17,
          start.dy + normal.dy * claw * 17,
        );
      for (var i = 1; i <= 24; i++) {
        final p =
            start +
            direction * (i / 24) +
            normal * (claw * 17 + math.sin(i * 2.6 + claw) * 2.5);
        path.lineTo(p.dx, p.dy);
      }
      final metric = path.computeMetrics().first;
      final cut = metric.extractPath(0, metric.length * progress);
      canvas.drawPath(
        cut,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF020405),
      );
      canvas.drawPath(
        cut,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFC8A36A).withValues(alpha: .8),
      );
      canvas.save();
      canvas.translate(normal.dx * 3, normal.dy * 3);
      canvas.drawPath(
        cut,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFFE0D4BA).withValues(alpha: .6),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_TornCoverPainter old) =>
      first != old.first || second != old.second || opening != old.opening;
}
