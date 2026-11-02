import 'dart:async';
import 'package:flutter/material.dart';
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
    _tear();
  }

  void _tear() {
    if (_time.value >= .44 && _struck.add(3)) widget.onTear?.call();
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
    backgroundColor: Colors.black,
    body: AnimatedBuilder(
      animation: _time,
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          if (_reduced)
            Center(
              child: Semantics(
                label: 'Logo de Mordeviel Legendary',
                image: true,
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Image.asset(
                      'assets/branding/logo.png',
                      width: 230,
                      height: 230,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            )
          else
            IgnorePointer(child: OpeningCurtain(progress: _time.value)),
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
