import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../audio/classic_audio.dart';
import '../services/immersion_preferences.dart';

const mereGrandOpeningDuration = Duration(milliseconds: 3900);
const mereGrandPosterAsset = 'assets/events/mere_grand_poster.png';

({double unroll, double title, double soon}) mereGrandOpeningAt(Duration time) {
  double phase(int start, int end) =>
      ((time.inMilliseconds - start) / (end - start)).clamp(0.0, 1.0);
  return (
    unroll: Curves.easeInOutCubic.transform(phase(0, 1700)),
    title: Curves.easeOut.transform(phase(1850, 2850)),
    soon: Curves.easeOut.transform(phase(3050, 3850)),
  );
}

class MereGrandPosterScreen extends StatefulWidget {
  const MereGrandPosterScreen({super.key, this.soundEnabled = true});
  final bool soundEnabled;
  @override
  State<MereGrandPosterScreen> createState() => _MereGrandPosterScreenState();
}

class _MereGrandPosterScreenState extends State<MereGrandPosterScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _opening = AnimationController(
    vsync: this,
    duration: mereGrandOpeningDuration,
  );
  ui.Image? _poster;
  AudioPlayer? _sound;
  String? _error;
  bool _foreground = true,
      _visible = true,
      _reduced = false,
      _preparedSound = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ClassicAudio.instance.addListener(_volume);
    unawaited(_load());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible = ModalRoute.of(context)?.isCurrent ?? true;
    _reduced = ImmersionPreferences.instance.reduced(context);
    if (_reduced) _finish();
    _syncPlayback();
  }

  Future<void> _load() async {
    try {
      final data = await rootBundle.load(mereGrandPosterAsset);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      _poster = frame.image;
      final settings = ClassicAudio.instance;
      if (widget.soundEnabled &&
          !_reduced &&
          !settings.muted &&
          settings.effectLevel > 0) {
        try {
          final sound = _sound = AudioPlayer();
          await sound.setSource(
            AssetSource('audio/classic/mere_grand_opening.wav'),
          );
          if (!mounted) return;
          await sound.setVolume(settings.effectLevel * .75);
          _preparedSound = true;
        } catch (_) {
          // An unavailable sound output must never block the poster.
        }
      }
      if (!mounted) return;
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncPlayback();
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'L’affiche ne peut pas être affichée pour le moment.',
        );
      }
    }
  }

  void _volume() {
    final settings = ClassicAudio.instance;
    unawaited(
      _sound
              ?.setVolume(settings.muted ? 0 : settings.effectLevel * .75)
              .catchError((Object _) {}) ??
          Future<void>.value(),
    );
  }

  void _syncPlayback() {
    if (_poster == null) return;
    if (!_foreground || !_visible) {
      _opening.stop(canceled: false);
      unawaited(
        _sound?.pause().catchError((Object _) {}) ?? Future<void>.value(),
      );
    } else if (!_opening.isCompleted) {
      _opening.forward();
      if (_preparedSound) {
        unawaited(
          _sound?.resume().catchError((Object _) {}) ?? Future<void>.value(),
        );
      }
    }
  }

  void _finish() {
    _opening.value = 1;
    unawaited(_sound?.stop().catchError((Object _) {}) ?? Future<void>.value());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncPlayback();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ClassicAudio.instance.removeListener(_volume);
    _opening.dispose();
    _poster?.dispose();
    unawaited(
      _sound?.dispose().catchError((Object _) {}) ?? Future<void>.value(),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF141916),
    body: SafeArea(
      child: AnimatedBuilder(
        animation: _opening,
        builder: (context, _) {
          final done = _opening.isCompleted;
          final frame = mereGrandOpeningAt(
            Duration(
              milliseconds:
                  (_opening.value * mereGrandOpeningDuration.inMilliseconds)
                      .round(),
            ),
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              if (_poster != null)
                GestureDetector(
                  onTap: done ? null : _finish,
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: done ? 3 : 1,
                    panEnabled: done,
                    scaleEnabled: done,
                    child: SizedBox.expand(
                      child: Semantics(
                        image: true,
                        label: done
                            ? 'La Soirée de Mère-Grand. Rubine, Pèlerine et le Loup. Bientôt disponible.'
                            : 'Le parchemin de Mère-Grand se déplie.',
                        child: CustomPaint(
                          painter: MereGrandScrollPainter(
                            image: _poster!,
                            unroll: frame.unroll,
                            title: frame.title,
                            soon: frame.soon,
                            sparks: !_reduced,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else if (_error != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, textAlign: TextAlign.center),
                  ),
                )
              else
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFFE4BD67)),
                ),
              Positioned(
                top: 12,
                right: 12,
                child: IconButton.filled(
                  tooltip: 'Fermer l’affiche',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: .65),
                    foregroundColor: const Color(0xFFF4DCAD),
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close),
                ),
              ),
              if (_poster != null && !done)
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: TextButton(
                      onPressed: _finish,
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: .65),
                        foregroundColor: const Color(0xFFF4DCAD),
                      ),
                      child: const Text('Passer l’animation'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

/// The exact original PNG is revealed in sections; the finished artwork is unchanged.
class MereGrandScrollPainter extends CustomPainter {
  const MereGrandScrollPainter({
    required this.image,
    required this.unroll,
    required this.title,
    required this.soon,
    this.sparks = true,
  });
  final ui.Image image;
  final double unroll, title, soon;
  final bool sparks;

  static const _titleRects = [
    Rect.fromLTWH(265, 109, 380, 73),
    Rect.fromLTWH(163, 181, 574, 108),
    Rect.fromLTWH(175, 289, 55, 12),
  ];
  static const _soonRect = Rect.fromLTWH(177, 1046, 550, 71);

  @override
  void paint(Canvas canvas, Size size) {
    final fitted = applyBoxFit(
      BoxFit.contain,
      const Size(896, 1199),
      size,
    ).destination;
    canvas.save();
    canvas.translate(
      (size.width - fitted.width) / 2,
      (size.height - fitted.height) / 2,
    );
    canvas.scale(fitted.width / 896, fitted.height / 1199);
    const full = Rect.fromLTWH(0, 0, 896, 1199);
    if (unroll >= 1) {
      _poster(canvas, full);
    } else {
      final gap = 160 + (1199 - 160) * unroll;
      final top = (1199 - gap) / 2, bottom = top + gap;
      const topRoll = 112.0, bottomRoll = 126.0;
      if (gap > topRoll + bottomRoll) {
        canvas.save();
        canvas.clipRect(
          Rect.fromLTRB(0, top + topRoll - 2, 896, bottom - bottomRoll + 2),
        );
        _poster(canvas, full);
        canvas.restore();
      }
      _roll(
        canvas,
        full,
        const Rect.fromLTWH(0, 0, 896, topRoll),
        Offset(0, top),
        upper: true,
      );
      _roll(
        canvas,
        full,
        const Rect.fromLTWH(0, 1199 - bottomRoll, 896, bottomRoll),
        Offset(0, bottom - bottomRoll),
        upper: false,
      );
      if (sparks) {
        final p = Paint()
          ..color = const Color(
            0xFFF4D580,
          ).withValues(alpha: math.sin(unroll * math.pi) * .65);
        for (var i = 0; i < 16; i++) {
          final x = 100 + ((i * 73 + unroll * 160) % 700);
          final y =
              (i.isEven ? top + topRoll : bottom - bottomRoll) +
              math.sin(i * 2.1 + unroll * 8) * 22;
          canvas.drawCircle(Offset(x, y), 1.5 + i % 3, p);
        }
      }
    }
    canvas.restore();
  }

  void _poster(Canvas canvas, Rect full) {
    final source = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    canvas.drawImageRect(
      image,
      source,
      full,
      Paint()..filterQuality = FilterQuality.high,
    );
    if (title < 1) {
      for (final rect in _titleRects) {
        canvas.drawRect(
          rect,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF201B1D), Color(0xFF251C1E), Color(0xFF1B1815)],
            ).createShader(rect),
        );
      }
      for (final rect in _titleRects) {
        _reveal(canvas, full, rect, title);
      }
    }
    if (soon < 1) {
      canvas.drawRect(
        _soonRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF7B192B), Color(0xFF741A2D), Color(0xFF761126)],
          ).createShader(_soonRect),
      );
      _reveal(canvas, full, _soonRect, soon);
    }
  }

  void _reveal(Canvas canvas, Rect full, Rect area, double progress) {
    if (progress <= 0) return;
    canvas.save();
    canvas.clipRect(area);
    canvas.saveLayer(
      area,
      Paint()..color = Colors.white.withValues(alpha: progress),
    );
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      full,
      Paint()..filterQuality = FilterQuality.high,
    );
    final edge = progress.clamp(.001, .999);
    canvas.drawRect(
      area,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = LinearGradient(
          colors: const [
            Colors.white,
            Colors.white,
            Colors.transparent,
            Colors.transparent,
          ],
          stops: [0, (edge - .12).clamp(0, edge), edge, 1],
        ).createShader(area),
    );
    canvas.restore();
    canvas.restore();
  }

  void _roll(
    Canvas canvas,
    Rect full,
    Rect section,
    Offset offset, {
    required bool upper,
  }) {
    final destination = offset & section.size;
    canvas.drawShadow(
      Path()..addRRect(
        RRect.fromRectAndRadius(
          destination.deflate(10),
          const Radius.circular(30),
        ),
      ),
      Colors.black.withValues(alpha: .75),
      12 * (1 - unroll),
      true,
    );
    canvas.save();
    canvas.clipRect(destination);
    canvas.translate(offset.dx - section.left, offset.dy - section.top);
    _poster(canvas, full);
    canvas.restore();
    final shadowEdge = upper ? destination.bottom - 10 : destination.top;
    canvas.drawRect(
      Rect.fromLTWH(60, shadowEdge, 776, 10),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: (1 - unroll) * .4),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(60, shadowEdge, 776, 10)),
    );
  }

  @override
  bool shouldRepaint(MereGrandScrollPainter old) =>
      old.image != image ||
      old.unroll != unroll ||
      old.title != title ||
      old.soon != soon ||
      old.sparks != sparks;
}
