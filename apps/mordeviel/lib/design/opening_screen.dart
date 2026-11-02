import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'game_theme.dart';
import 'opening_curtain.dart';

/// Une ouverture finie, sans pourcentage fictif : l'accueil attend aussi [ready].
class OpeningScreen extends StatefulWidget {
  const OpeningScreen({
    super.key,
    this.ready,
    required this.onStart,
    required this.onScratch,
    required this.onComplete,
    this.onTear,
  });
  final VoidCallback? onTear;
  final Future<void>? ready;
  final VoidCallback onStart, onComplete;
  final ValueChanged<int> onScratch;
  @override
  State<OpeningScreen> createState() => _OpeningScreenState();
}

class _OpeningScreenState extends State<OpeningScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _curtainMilliseconds = 3800;
  static const _totalMilliseconds = 5600;
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
            duration: const Duration(milliseconds: _totalMilliseconds),
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
      if (_curtainProgress >= threshold && _struck.add(strike)) {
        widget.onScratch(strike);
      }
    }
    _tear();
  }

  void _tear() {
    if (_curtainProgress >= .44 && _struck.add(3)) widget.onTear?.call();
  }

  double get _curtainProgress =>
      (_time.value * _totalMilliseconds / _curtainMilliseconds).clamp(0, 1);

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
    backgroundColor: Colors.black,
    body: AnimatedBuilder(
      animation: _time,
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          // Le rideau découvre le chargement ; l'accueil vient après le reflet.
          ExcludeSemantics(
            excluding: !_reduced && _curtainProgress < .95,
            child: _LogoLoading(
              progress: _reduced
                  ? 1
                  : ((_time.value * _totalMilliseconds - 3600) / 2000).clamp(
                      0,
                      1,
                    ),
              reduced: _reduced,
            ),
          ),
          if (!_reduced && _curtainProgress < 1)
            IgnorePointer(child: OpeningCurtain(progress: _curtainProgress)),
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
      ),
    ),
  );
}

/// L'ancien écran de chargement, révélé sous les pans déchirés.
class _LogoLoading extends StatelessWidget {
  const _LogoLoading({required this.progress, required this.reduced});
  final double progress;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    final sweep = ((progress - .08) / .7).clamp(0, 1);
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          colors: [Color(0xFF29342D), GameTheme.ink],
          radius: .8,
        ),
      ),
      child: Center(
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
                                alpha: reduced
                                    ? .07
                                    : .06 + .04 * math.sin(progress * math.pi),
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
                                  reduced
                                      ? Colors.transparent
                                      : const Color(0xDFFFF4D9),
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: GameTheme.ivory),
                ),
                const SizedBox(height: 16),
                Semantics(
                  label: 'Ouverture du village',
                  child: SizedBox(
                    width: 110,
                    height: 2,
                    child: LinearProgressIndicator(
                      value: progress,
                      color: GameTheme.gold,
                      backgroundColor: GameTheme.gold.withValues(alpha: .15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
