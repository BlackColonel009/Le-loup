import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../services/immersion_preferences.dart';

/// A sheet bends around a cylinder; its two faces can be visible together.
/// The root stays on the binding, while the leading edge follows the finger.
({Offset position, double angle}) codexCurlPoint({
  required Size size,
  required bool doublePage,
  required bool forward,
  required double progress,
  required double u,
  required double v,
  double finger = .65,
  double gutter = 8,
}) {
  final p = progress.clamp(0.0, 1.0);
  final width = doublePage ? (size.width - gutter) / 2 : size.width;
  final lift = math.sin(p * math.pi);
  final bend = 1.45 * lift;
  final skew = (finger - .5) * 2;
  final theta = p * math.pi + skew * lift * (v - .5) * .30;
  final start = theta - bend / 2;
  final angle = theta + bend * (u - .5);
  final x = bend.abs() < .00001
      ? width * u * math.cos(theta)
      : width * (math.sin(angle) - math.sin(start)) / bend;
  final z = bend.abs() < .00001
      ? width * u * math.sin(theta)
      : width * (math.cos(start) - math.cos(angle)) / bend;
  final perspective = 1 / (1 - z / (math.max(width, size.height) * 5));
  final hinge = doublePage
      ? width + gutter * (forward ? 1 - p : p)
      : forward
      ? 0.0
      : size.width;
  return (
    position: Offset(
      hinge + (forward ? x : -x) * perspective,
      v * size.height +
          lift * u * (.5 - v) * 14 +
          skew * math.sin(v * math.pi) * math.sin(u * math.pi) * lift * 9,
    ),
    angle: angle,
  );
}

/// The real Flutter page is photographed once per gesture, never per frame.
/// Two textured meshes provide readable recto/verso with moving fold lighting.
class CodexPageTurn extends StatefulWidget {
  const CodexPageTurn({
    super.key,
    required this.index,
    required this.count,
    required this.doublePage,
    required this.layoutToken,
    required this.pageBuilder,
    required this.onChanged,
    this.gutter = 8,
  });
  final int index, count;
  final bool doublePage;
  final Object layoutToken;
  final Widget Function(int leaf, bool left) pageBuilder;
  final ValueChanged<int> onChanged;
  final double gutter;
  @override
  CodexPageTurnState createState() => CodexPageTurnState();
}

class CodexPageTurnState extends State<CodexPageTurn>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion;
  final _currentLeft = GlobalKey(), _currentRight = GlobalKey();
  final _targetLeft = GlobalKey(), _targetRight = GlobalKey();
  ui.Image? _front, _back;
  int _index = 0, _generation = 0;
  int? _target;
  bool _dragging = false, _settling = false, _commit = false, _reduced = false;
  bool _paused = false;
  double _distance = 0, _baseProgress = 0, _finger = .65;
  bool get _forward => (_target ?? _index + 1) > _index;
  int get _perSpread => widget.doublePage ? 2 : 1;
  @override
  void initState() {
    super.initState();
    _index = widget.index;
    _motion =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 880),
        )..addStatusListener((status) {
          if (_settling &&
              (status == AnimationStatus.completed ||
                  status == AnimationStatus.dismissed)) {
            _complete(_commit);
          }
        });
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = ImmersionPreferences.instance.reduced(context);
    if (_reduced && _target != null) {
      _motion.stop();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _target != null) _complete(true);
      });
    }
  }

  @override
  void didUpdateWidget(CodexPageTurn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.layoutToken != oldWidget.layoutToken ||
        widget.count != oldWidget.count) {
      _cancel();
      _index = widget.index;
    } else if (_target == null && widget.index != _index) {
      _index = widget.index;
    }
  }

  void _dropImages() {
    final front = _front, back = _back;
    _front = null;
    _back = null;
    if (front != null || back != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        front?.dispose();
        back?.dispose();
      });
    }
  }

  void _cancel() {
    _generation++;
    _settling = false;
    _dragging = false;
    _target = null;
    _motion.stop();
    _motion.value = 0;
    _dropImages();
  }

  void _complete(bool commit) {
    if (!mounted || _target == null) return;
    final target = _target!;
    setState(() {
      if (commit) _index = target;
      _cancel();
    });
    if (commit) widget.onChanged(target);
  }

  void turnTo(int target) {
    if (_target != null ||
        target == _index ||
        target < 0 ||
        target >= widget.count) {
      return;
    }
    if (_reduced) {
      setState(() => _index = target);
      widget.onChanged(target);
      return;
    }
    _prepare(target, dragging: false);
  }

  void _prepare(int target, {required bool dragging}) {
    if (target < 0 || target >= widget.count) return;
    final generation = ++_generation;
    setState(() {
      _target = target;
      _dragging = dragging;
      _commit = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation || _target == null) return;
      try {
        final frontKey = widget.doublePage && _forward
            ? _currentRight
            : _currentLeft;
        final backKey = widget.doublePage && !_forward
            ? _targetRight
            : _targetLeft;
        final frontBoundary =
            frontKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final backBoundary =
            backKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final ratio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 1.75);
        _front = frontBoundary.toImageSync(pixelRatio: ratio);
        _back = backBoundary.toImageSync(pixelRatio: ratio);
        setState(() {});
        if (!_dragging) _settle(_commit, programmatic: !dragging);
      } catch (_) {
        // Preserve navigation on a surface that cannot capture a layer.
        _complete(true);
      }
    });
  }

  void _settle(bool commit, {bool programmatic = false}) {
    _commit = commit;
    if (_front == null) return;
    final target = commit ? 1.0 : 0.0;
    if ((_motion.value - target).abs() < .001) {
      _complete(commit);
      return;
    }
    _settling = true;
    if (_paused) return;
    _motion
        .animateTo(
          target,
          duration: Duration(
            milliseconds: programmatic
                ? 880
                : ((target - _motion.value).abs() * 820).round().clamp(
                    180,
                    820,
                  ),
          ),
          curve: programmatic ? Curves.easeInOutCubic : Curves.easeOutCubic,
        )
        .whenComplete(() {
          if (mounted &&
              _settling &&
              !_motion.isAnimating &&
              !_dragging &&
              !_paused &&
              (_motion.value - target).abs() < .001) {
            _complete(commit);
          }
        });
  }

  double get _leafWidth {
    final box = context.findRenderObject() as RenderBox;
    return widget.doublePage
        ? (box.size.width - widget.gutter) / 2
        : box.size.width;
  }

  void _dragStart(DragStartDetails details) {
    _distance = 0;
    _baseProgress = _target == null ? 0 : _motion.value;
    _dragging = true;
    _settling = false;
    _motion.stop();
    final box = context.findRenderObject() as RenderBox;
    _finger = (details.localPosition.dy / box.size.height).clamp(0, 1);
  }

  void _dragUpdate(DragUpdateDetails details) {
    _distance += details.delta.dx;
    if (_target == null && _distance.abs() > 5) {
      final next = _index + (_distance < 0 ? 1 : -1);
      if (_reduced) return;
      if (next < 0 || next >= widget.count) return;
      _prepare(next, dragging: true);
    }
    if (_target == null) return;
    _motion.value =
        (_baseProgress + (_forward ? -_distance : _distance) / _leafWidth)
            .clamp(0.0, .995);
  }

  void _dragEnd(DragEndDetails details) {
    if (_reduced) {
      _dragging = false;
      if (_distance.abs() > 35) turnTo(_index + (_distance < 0 ? 1 : -1));
      return;
    }
    if (_target == null) {
      _dragging = false;
      return;
    }
    final velocity = (_forward ? -1 : 1) * (details.primaryVelocity ?? 0);
    final commit = velocity.abs() > 420 ? velocity > 0 : _motion.value > .38;
    _dragging = false;
    _settle(commit);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
    if (_paused) {
      _motion.stop();
    } else if (_settling) {
      _settle(_commit);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _motion.dispose();
    _front?.dispose();
    _back?.dispose();
    super.dispose();
  }

  Widget _spread(int spread, {required bool target}) => Row(
    children: [
      for (var side = 0; side < _perSpread; side++) ...[
        if (side > 0) SizedBox(width: widget.gutter),
        Expanded(
          child: Opacity(
            opacity:
                !target &&
                    _front != null &&
                    (widget.doublePage ? side == (_forward ? 1 : 0) : true)
                ? 0
                : 1,
            child: RepaintBoundary(
              key: target
                  ? side == 0
                        ? _targetLeft
                        : _targetRight
                  : side == 0
                  ? _currentLeft
                  : _currentRight,
              child: widget.pageBuilder(
                spread * _perSpread + side,
                widget.doublePage && side == 0,
              ),
            ),
          ),
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) => GestureDetector(
    key: const ValueKey('codex-paper-gesture'),
    behavior: HitTestBehavior.opaque,
    onHorizontalDragStart: _dragStart,
    onHorizontalDragUpdate: _dragUpdate,
    onHorizontalDragEnd: _dragEnd,
    onHorizontalDragCancel: () {
      _dragging = false;
      if (_target != null) _settle(false);
    },
    child: ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            excluding: _target != null,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_target != null) _spread(_target!, target: true),
                if (widget.count > 0) _spread(_index, target: false),
              ],
            ),
          ),
          if (_front != null && _back != null)
            IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  key: const ValueKey('codex-curled-sheet'),
                  painter: CodexCurlPainter(
                    front: _front!,
                    back: _back!,
                    progress: _motion,
                    doublePage: widget.doublePage,
                    forward: _forward,
                    finger: () => _finger,
                    gutter: widget.gutter,
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class CodexCurlPainter extends CustomPainter {
  CodexCurlPainter({
    required this.front,
    required this.back,
    required this.progress,
    required this.doublePage,
    required this.forward,
    required this.finger,
    required this.gutter,
  }) : super(repaint: progress);
  final ui.Image front, back;
  final Animation<double> progress;
  final bool doublePage, forward;
  final double Function() finger;
  final double gutter;
  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.value;
    final lift = math.sin(p * math.pi);
    const columns = 52, rows = 10;
    final positions = [<double>[], <double>[]],
        textures = [<double>[], <double>[]],
        shades = [<int>[], <int>[]];
    ({Offset position, double angle}) point(double u, double v) =>
        codexCurlPoint(
          size: size,
          doublePage: doublePage,
          forward: forward,
          progress: p,
          u: u,
          v: v,
          finger: finger(),
          gutter: gutter,
        );
    final outline = Path();
    for (var y = 0; y <= rows; y++) {
      final q = point(0, y / rows).position;
      if (y == 0) {
        outline.moveTo(q.dx, q.dy);
      } else {
        outline.lineTo(q.dx, q.dy);
      }
    }
    for (var y = rows; y >= 0; y--) {
      final q = point(1, y / rows).position;
      outline.lineTo(q.dx, q.dy);
    }
    outline.close();
    if (lift > .01) {
      canvas.save();
      canvas.translate((forward ? -1 : 1) * lift * 9, lift * 5);
      canvas.drawPath(
        outline,
        Paint()
          ..color = Colors.black.withValues(alpha: .26 * lift)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 + lift * 12),
      );
      canvas.restore();
    }
    for (var x = 0; x < columns; x++) {
      for (var y = 0; y < rows; y++) {
        final a = x / columns,
            b = (x + 1) / columns,
            c = y / rows,
            d = (y + 1) / rows;
        final face = math.cos(point((a + b) / 2, (c + d) / 2).angle) >= 0
            ? 0
            : 1;
        final image = face == 0 ? front : back;
        for (final (u, v) in [(a, c), (b, c), (a, d), (b, c), (b, d), (a, d)]) {
          final q = point(u, v);
          positions[face].addAll([q.position.dx, q.position.dy]);
          final tx = (face == 0 ? forward : !forward) ? u : 1 - u;
          textures[face].addAll([tx * image.width, v * image.height]);
          final lighting = .76 + .24 * math.cos(q.angle).abs();
          shades[face].add(
            Color.fromARGB(
              255,
              (255 * lighting).round(),
              ((face == 0 ? 255 : 255 - 10 * lift) * lighting).round(),
              ((face == 0 ? 255 : 255 - 26 * lift) * lighting).round(),
            ).toARGB32(),
          );
        }
      }
    }
    for (var face = 0; face < 2; face++) {
      if (positions[face].isEmpty) continue;
      final vertices = ui.Vertices.raw(
        ui.VertexMode.triangles,
        Float32List.fromList(positions[face]),
        textureCoordinates: Float32List.fromList(textures[face]),
        colors: Int32List.fromList(shades[face]),
      );
      final shader = ui.ImageShader(
        face == 0 ? front : back,
        TileMode.clamp,
        TileMode.clamp,
        Matrix4.identity().storage,
        filterQuality: FilterQuality.medium,
      );
      canvas.drawVertices(
        vertices,
        BlendMode.modulate,
        Paint()..shader = shader,
      );
      vertices.dispose();
      shader.dispose();
    }
    final edge = Path();
    for (var y = 0; y <= rows; y++) {
      final q = point(1, y / rows).position;
      if (y == 0) {
        edge.moveTo(q.dx, q.dy);
      } else {
        edge.lineTo(q.dx, q.dy);
      }
    }
    canvas.drawPath(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .9
        ..color = const Color(0xFFF9EDCD).withValues(alpha: .8 * lift),
    );
  }

  @override
  bool shouldRepaint(CodexCurlPainter old) =>
      front != old.front ||
      back != old.back ||
      doublePage != old.doublePage ||
      forward != old.forward ||
      gutter != old.gutter;
}
