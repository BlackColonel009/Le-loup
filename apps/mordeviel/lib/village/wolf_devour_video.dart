import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../cards/card_gallery.dart';
import '../cards/classic_role.dart';
import '../content/content_image.dart';

const wolfDevourVideoAsset = 'assets/village/horror/wolf_devour_clean.mp4';
const whiteWolfDevourVideoAsset =
    'assets/village/horror/white_wolf_devour_clean.mp4';
const wolfDevourVideoDurationMilliseconds = 10030;
const wolfRoleCardIds = {'werewolf', 'alpha_wolf', 'wolf_father', 'white_wolf'};

double wolfDevourCardRevealProgress(double deathProgress) =>
    Curves.easeInOut.transform(((deathProgress - .04) / .12).clamp(0.0, 1.0));

String? wolfDevourVideoFor({
  required String cause,
  required CardAmbience ambience,
  required String? role,
}) {
  if (ambience != CardAmbience.horror || role == null) return null;
  if (cause == 'white_wolf' && wolfRoleCardIds.contains(role)) {
    return whiteWolfDevourVideoAsset;
  }
  if (cause == 'night' || cause == 'white_wolf') {
    return wolfDevourVideoAsset;
  }
  return null;
}

class WolfDevourVideo extends StatefulWidget {
  const WolfDevourVideo({
    super.key,
    required this.role,
    required this.videoPath,
    required this.whiteWolfFinishing,
    required this.concealed,
    required this.onPlaybackStarted,
    required this.onPlaybackFailed,
    this.onPlaybackCompleted,
  });

  final ClassicRole role;
  final String videoPath;
  final bool whiteWolfFinishing;
  final bool concealed;
  final VoidCallback onPlaybackStarted;
  final VoidCallback onPlaybackFailed;
  final VoidCallback? onPlaybackCompleted;

  @override
  State<WolfDevourVideo> createState() => _WolfDevourVideoState();
}

class _WolfDevourVideoState extends State<WolfDevourVideo>
    with WidgetsBindingObserver {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _failed = false;
  bool _needsReveal = false;
  bool _completionNotified = false;
  late bool _foreground;
  Future<void> _playback = Future<void>.value();

  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    _controller = VideoPlayerController.file(
      File(widget.videoPath),
      // This widget controls pause and resume, including the privacy mask.
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: true,
      ),
    )..addListener(_onVideoChanged);
    unawaited(_prepareVideo());
  }

  Future<void> _prepareVideo() async {
    try {
      await _controller.initialize().timeout(const Duration(seconds: 8));
      if (!mounted) return;
      await _controller.setLooping(false);
      if (!mounted) return;
      setState(() => _ready = true);
      _syncPlayback();
    } catch (error, stackTrace) {
      _fail(error, stackTrace);
    }
  }

  void _onVideoChanged() {
    if (!mounted) return;
    final value = _controller.value;
    if (value.hasError) {
      _fail(
        StateError(value.errorDescription ?? 'Lecture vidéo impossible.'),
        StackTrace.current,
      );
    } else {
      setState(() {});
      if (value.isCompleted) _notifyCompletion();
    }
  }

  void _fail(Object error, StackTrace stackTrace) {
    if (_failed) return;
    _failed = true;
    debugPrint('Vidéo de dévoration indisponible : $error\n$stackTrace');
    if (mounted) widget.onPlaybackFailed();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _needsReveal = true;
    _syncPlayback();
  }

  @override
  void didUpdateWidget(covariant WolfDevourVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.concealed != oldWidget.concealed) {
      if (!widget.concealed) _needsReveal = false;
      _syncPlayback();
    }
  }

  bool get _canPlay => _foreground && !widget.concealed && !_needsReveal;

  void _notifyCompletion() {
    if (_completionNotified || !_canPlay) return;
    _completionNotified = true;
    widget.onPlaybackCompleted?.call();
  }

  void _syncPlayback() {
    _playback = _playback
        .then((_) async {
          if (!mounted || !_ready || _failed) return;
          if (_controller.value.isCompleted) {
            _notifyCompletion();
            return;
          }
          final play = _canPlay;
          if (play == _controller.value.isPlaying) return;
          if (play) {
            await _controller.play();
            if (mounted && _canPlay && !_failed) widget.onPlaybackStarted();
          } else {
            await _controller.pause();
          }
        })
        .catchError((Object error, StackTrace stackTrace) {
          if (mounted) _fail(error, stackTrace);
        });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onVideoChanged);
    unawaited(_controller.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.expand();
    if (!_ready || widget.concealed) {
      return const ColoredBox(color: Color(0xFF080B10));
    }
    final value = _controller.value;
    final pose = _wolfDevourPose(
      value.position,
      whiteWolfFinishing: widget.whiteWolfFinishing,
    );
    final reveal = wolfDevourCardRevealProgress(
      value.position.inMilliseconds / wolfDevourVideoDurationMilliseconds,
    );
    final front = RoleCardFront(
      role: widget.role,
      ambience: CardAmbience.horror,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Stack(
          fit: StackFit.expand,
          children: [
            VideoPlayer(_controller),
            if (pose.opacity > 0)
              Positioned(
                left: size.width * pose.left,
                top: size.height * pose.top,
                width: size.width * pose.width,
                height: size.height * pose.height,
                child: Transform.rotate(
                  angle: pose.rotation,
                  child: Opacity(
                    opacity: pose.opacity,
                    child: ClipPath(
                      clipper: _WolfBiteClipper(pose.bite),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Opacity(
                            opacity: 1 - reveal,
                            child: const ContentImage(
                              'assets/village/horror/card_back.png',
                              fit: BoxFit.fill,
                              fallbackAsset: 'assets/village/card_back.png',
                            ),
                          ),
                          Opacity(
                            opacity: reveal,
                            child: CustomPaint(
                              foregroundPainter: _CrushedPaperFold(pose.bite),
                              child: FittedBox(
                                fit: BoxFit.fill,
                                child: SizedBox(
                                  width: 200,
                                  height: 300,
                                  child: front,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _WolfDevourPose {
  const _WolfDevourPose({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.bite,
    required this.opacity,
    required this.rotation,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final double bite;
  final double opacity;
  final double rotation;

  static const keyframes = [
    (0.0, .278, .462, .444, .333, 0.0, 1.0, -.030),
    (1.6, .266, .441, .468, .351, 0.0, 1.0, .020),
    (3.55, .278, .419, .444, .333, 0.0, 1.0, -.020),
    (4.60, .295, .410, .410, .308, 0.0, 1.0, .015),
    // The teeth start to close around 4.65 s. Keep the fold at their contact point.
    (4.67, .310, .475, .380, .217, .10, 1.0, -.062),
    (4.75, .341, .542, .318, .112, .28, 1.0, .093),
    (4.83, .392, .580, .216, .043, .55, .82, -.085),
    (4.98, .443, .591, .114, .012, .86, 0.0, .040),
  ];

  static const whiteWolfKeyframes = [
    (0.0, .280, .460, .440, .330, 0.0, 1.0, -.023),
    (2.5, .275, .453, .450, .338, 0.0, 1.0, .012),
    (2.77, .298, .472, .426, .317, 0.0, 1.0, .105),
    (3.3, .281, .457, .438, .329, 0.0, 1.0, .024),
    (3.78, .275, .479, .430, .312, 0.0, 1.0, -.122),
    (4.55, .284, .468, .432, .324, 0.0, 1.0, -.026),
    (6.50, .286, .445, .428, .321, 0.0, 1.0, .015),
    (7.40, .294, .439, .412, .309, 0.0, 1.0, -.021),
    // The burst begins inside the open jaws at about 7.7 s.
    (7.57, .322, .463, .356, .216, .12, 1.0, .065),
    (7.67, .361, .501, .278, .103, .36, 1.0, -.075),
    (7.73, .411, .527, .164, .036, .60, .68, .095),
    (7.81, .457, .542, .070, .010, .88, 0.0, -.041),
  ];
}

_WolfDevourPose _wolfDevourPose(
  Duration position, {
  required bool whiteWolfFinishing,
}) {
  final seconds = position.inMicroseconds / Duration.microsecondsPerSecond;
  final frames = whiteWolfFinishing
      ? _WolfDevourPose.whiteWolfKeyframes
      : _WolfDevourPose.keyframes;
  if (seconds <= frames.first.$1) return _poseFrom(frames.first);
  for (var index = 1; index < frames.length; index++) {
    final previous = frames[index - 1];
    final next = frames[index];
    if (seconds > next.$1) continue;
    final progress = ((seconds - previous.$1) / (next.$1 - previous.$1)).clamp(
      0.0,
      1.0,
    );
    final eased = Curves.easeInOut.transform(progress);
    return _WolfDevourPose(
      left: _lerp(previous.$2, next.$2, eased),
      top: _lerp(previous.$3, next.$3, eased),
      width: _lerp(previous.$4, next.$4, eased),
      height: _lerp(previous.$5, next.$5, eased),
      bite: _lerp(previous.$6, next.$6, eased),
      opacity: _lerp(previous.$7, next.$7, eased),
      rotation: _lerp(previous.$8, next.$8, eased),
    );
  }
  return _poseFrom(frames.last);
}

_WolfDevourPose _poseFrom(
  (double, double, double, double, double, double, double, double) frame,
) => _WolfDevourPose(
  left: frame.$2,
  top: frame.$3,
  width: frame.$4,
  height: frame.$5,
  bite: frame.$6,
  opacity: frame.$7,
  rotation: frame.$8,
);

double _lerp(double start, double end, double progress) =>
    start + (end - start) * progress;

class _CrushedPaperFold extends CustomPainter {
  const _CrushedPaperFold(this.pressure);
  final double pressure;

  @override
  void paint(Canvas canvas, Size size) {
    if (pressure == 0) return;
    final crease = Path()
      ..moveTo(0, size.height * .42)
      ..lineTo(size.width * .41, size.height * .67)
      ..lineTo(size.width * .67, size.height * .51)
      ..lineTo(size.width, size.height * .72);
    canvas.drawPath(
      crease,
      Paint()
        ..color = Colors.black.withValues(alpha: pressure * .88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * .17
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawPath(
      crease,
      Paint()
        ..color = const Color(0xFFF3C392).withValues(alpha: pressure * .48)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _CrushedPaperFold old) =>
      old.pressure != pressure;
}

class _WolfBiteClipper extends CustomClipper<Path> {
  const _WolfBiteClipper(this.progress);

  final double progress;

  @override
  Path getClip(Size size) {
    final bite = progress.clamp(0.0, 1.0);
    if (bite == 0) return Path()..addRect(Offset.zero & size);
    if (bite == 1) return Path();
    final path = Path()..moveTo(0, size.height * bite);
    for (var index = 1; index <= 40; index++) {
      final x = size.width * index / 40;
      final teeth = math.sin(index * 2.71) * size.height * .012 * bite;
      path.lineTo(x, (size.height * bite + teeth).clamp(0.0, size.height));
    }
    return path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _WolfBiteClipper oldClipper) =>
      oldClipper.progress != progress;
}
