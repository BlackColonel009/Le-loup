import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'game_theme.dart';

/// La vidéo de Logan reste locale ; aucune connexion ni pack n'est nécessaire.
class OpeningScreen extends StatefulWidget {
  const OpeningScreen({
    super.key,
    this.ready,
    this.volume = .65,
    required this.onStart,
    required this.onComplete,
  });
  static const videoAsset = 'assets/branding/opening/intro_gemini.mp4';
  final Future<void>? ready;
  final double volume;
  final VoidCallback onStart, onComplete;
  @override
  State<OpeningScreen> createState() => _OpeningScreenState();
}

class _OpeningScreenState extends State<OpeningScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _video;
  Future<void> _media = Future.value();
  Timer? _watchdog, _fallbackDelay;
  Duration _position = Duration.zero;
  int _stalled = 0;
  bool _ready = false, _prepared = false, _loaded = false;
  bool _started = false, _finished = false, _paused = false;
  bool _skip = false, _reduced = false, _fallback = false, _ended = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.ready == null) {
      _ready = true;
    } else {
      unawaited(_waitForReady());
    }
  }

  Future<void> _waitForReady() async {
    try {
      await widget.ready;
    } catch (_) {
      // Une sortie audio indisponible ne doit pas bloquer l'accès au jeu.
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _finished) return;
      if (_reduced) {
        _syncPlayback();
        _begin();
      } else if (!_prepared && !_skip) {
        _prepared = true;
        unawaited(_prepareVideo());
      } else {
        _begin();
      }
    });
  }

  Future<void> _prepareVideo() async {
    final controller = VideoPlayerController.asset(
      OpeningScreen.videoAsset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    _video = controller;
    controller.addListener(_onVideo);
    try {
      await controller.initialize().timeout(const Duration(seconds: 6));
      if (!mounted || _finished || _fallback) return;
      await controller.setLooping(false);
      if (!mounted || _finished || _fallback) return;
      setState(() => _loaded = true);
      _watchdog = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_paused || !_started || _finished || _skip || _reduced) return;
        final value = controller.value;
        if (value.position != _position) {
          _position = value.position;
          _stalled = 0;
        } else if (++_stalled >= 8) {
          _useFallback();
        }
      });
      _begin();
    } catch (_) {
      _useFallback();
    }
  }

  @override
  void didUpdateWidget(OpeningScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.volume != oldWidget.volume) _syncPlayback();
  }

  void _begin() {
    if (!_ready || _finished || _paused || !mounted) return;
    if (!_started) {
      _started = true;
      widget.onStart();
    }
    if (_skip || _ended) {
      unawaited(_finish());
    } else if (_fallback || _reduced) {
      _fallbackDelay ??= Timer(const Duration(milliseconds: 650), () {
        _fallbackDelay = null;
        _ended = true;
        _begin();
      });
    } else if (_loaded) {
      _syncPlayback();
    }
  }

  // Les changements de focus, de volume et le bouton Passer sont sérialisés.
  void _syncPlayback() {
    _media = _media
        .then<void>((_) async {
          final controller = _video;
          if (!mounted ||
              controller == null ||
              !controller.value.isInitialized) {
            return;
          }
          if (_ready &&
              _loaded &&
              !_paused &&
              !_finished &&
              !_skip &&
              !_reduced &&
              !_fallback) {
            await controller.setVolume(widget.volume.clamp(0, 1));
            // L'état peut avoir changé pendant l'appel natif setVolume.
            if (mounted &&
                !_paused &&
                !_finished &&
                !_skip &&
                !_fallback &&
                !_reduced) {
              await controller.play();
            }
          } else {
            await controller.pause();
          }
        })
        .catchError((Object _) => _useFallback());
  }

  void _onVideo() {
    if (!mounted || _finished) return;
    final value = _video!.value;
    if (value.hasError) {
      _useFallback();
    } else if (value.isCompleted) {
      _ended = true;
      _begin();
    }
  }

  void _useFallback() {
    if (!mounted || _finished || _fallback) return;
    _watchdog?.cancel();
    setState(() => _fallback = true);
    _syncPlayback();
    _begin();
  }

  Future<void> _finish() async {
    if (_finished || !_ready || _paused) return;
    _finished = true;
    _fallbackDelay?.cancel();
    _watchdog?.cancel();
    _syncPlayback();
    // Couper le son avant que l'accueil ne joue son hurlement.
    try {
      await _media.timeout(const Duration(seconds: 1));
    } catch (_) {
      // Le lecteur sera également libéré à la fermeture de l'écran.
    }
    if (!mounted) return;
    if (_paused) {
      _finished = false;
      _ended = true;
      return;
    }
    widget.onComplete();
  }

  void _skipOpening() {
    _skip = true;
    _syncPlayback();
    _begin();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
    _stalled = 0;
    if (_paused) {
      _fallbackDelay?.cancel();
      _fallbackDelay = null;
      _syncPlayback();
    } else {
      _begin();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watchdog?.cancel();
    _fallbackDelay?.cancel();
    final controller = _video;
    if (controller != null) {
      controller.removeListener(_onVideo);
      unawaited(controller.dispose().catchError((Object _) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      fit: StackFit.expand,
      children: [
        if (_reduced || _fallback)
          const _StaticLogo()
        else if (_loaded)
          ExcludeSemantics(
            child: OpeningVideoStage(
              videoSize: _video!.value.size,
              backdrop: VideoPlayer(_video!),
              child: VideoPlayer(_video!),
            ),
          )
        else
          const Center(
            child: SizedBox(
              width: 90,
              child: LinearProgressIndicator(
                minHeight: 2,
                color: GameTheme.gold,
                backgroundColor: Color(0x332E2619),
              ),
            ),
          ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: GameTheme.ivory,
                  backgroundColor: Colors.black.withValues(alpha: .55),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onPressed: _skipOpening,
                child: const Text('Passer'),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Même vidéo et même cadrage après rotation, sans étirement ni logo coupé.
/// Une seconde vue de la même texture remplit les marges, sans second décodage.
class OpeningVideoStage extends StatelessWidget {
  const OpeningVideoStage({
    super.key,
    required this.videoSize,
    required this.child,
    required this.backdrop,
  });
  final Size videoSize;
  final Widget child, backdrop;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final size = videoSize.isEmpty ? const Size(1280, 720) : videoSize;
      final extraSpace =
          (bounds.maxWidth / bounds.maxHeight - size.aspectRatio).abs() > .08;
      Widget fitted(Widget view, BoxFit fit) => FittedBox(
        fit: fit,
        child: SizedBox(width: size.width, height: size.height, child: view),
      );
      return ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (extraSpace)
              ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: fitted(backdrop, BoxFit.cover),
              ),
            if (extraSpace) const ColoredBox(color: Color(0xAA000000)),
            fitted(child, BoxFit.contain),
          ],
        ),
      );
    },
  );
}

class _StaticLogo extends StatelessWidget {
  const _StaticLogo();
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: RadialGradient(
        colors: [Color(0xFF29342D), GameTheme.ink],
        radius: .8,
      ),
    ),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(56),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 330, maxHeight: 330),
            child: Image.asset(
              'assets/branding/logo.png',
              fit: BoxFit.contain,
              semanticLabel: 'Logo de Mordeviel Legendary',
            ),
          ),
        ),
      ),
    ),
  );
}
