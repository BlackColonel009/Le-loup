import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Keeps the world inside its viewport, independently of the world's aspect
/// ratio. At overview scale, unused space stays centred and does not force zoom.
class VillageCameraController extends TransformationController {
  VillageCameraController({
    required this.world,
    required this.viewport,
    required double initialScale,
    Offset? focus,
  }) {
    _frame(focus ?? world.center(Offset.zero), initialScale);
  }

  final Size world;
  final Size viewport;
  double get minScale =>
      math.min(viewport.width / world.width, viewport.height / world.height);
  double get maxScale => math.max(2, minScale);

  @override
  set value(Matrix4 matrix) {
    final requested = matrix.getMaxScaleOnAxis();
    if (!requested.isFinite ||
        requested <= 0 ||
        !matrix.storage.every((v) => v.isFinite)) {
      return;
    }
    final scale = requested.clamp(minScale, maxScale);
    final center = viewport.center(Offset.zero);
    final focus = Offset(
      (center.dx - matrix.entry(0, 3)) / requested,
      (center.dy - matrix.entry(1, 3)) / requested,
    );
    double translation(double view, double world, double target) =>
        world * scale <= view
        ? (view - world * scale) / 2
        : target.clamp(view - world * scale, 0).toDouble();
    final next = Matrix4.identity()
      ..translateByDouble(
        translation(viewport.width, world.width, center.dx - focus.dx * scale),
        translation(
          viewport.height,
          world.height,
          center.dy - focus.dy * scale,
        ),
        0,
        1,
      )
      // InteractiveViewer measures all three axes to determine the zoom.
      // Leaving Z at 1 makes every reduced map appear to be at 100% scale.
      ..scaleByDouble(scale, scale, scale, 1);
    if (next != super.value) super.value = next;
  }

  void _frame(Offset focus, double scale) {
    final clamped = scale.clamp(minScale, maxScale);
    value = Matrix4.identity()
      ..translateByDouble(
        viewport.width / 2 - focus.dx * clamped,
        viewport.height / 2 - focus.dy * clamped,
        0,
        1,
      )
      ..scaleByDouble(clamped, clamped, clamped, 1);
  }

  void overview() => _frame(world.center(Offset.zero), minScale);

  void zoomBy(double factor) => _frame(
    toScene(viewport.center(Offset.zero)),
    value.getMaxScaleOnAxis() * factor,
  );

  VillageCameraController forViewport(Size next) => VillageCameraController(
    world: world,
    viewport: next,
    initialScale:
        value.getMaxScaleOnAxis() /
        minScale *
        math.min(next.width / world.width, next.height / world.height),
    focus: toScene(viewport.center(Offset.zero)),
  );
}
