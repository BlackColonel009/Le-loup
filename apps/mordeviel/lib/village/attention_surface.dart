import 'package:flutter/material.dart';
import '../services/immersion_preferences.dart';

/// Two soft beats on a new cue, then a steady border; never an endless flash.
class AttentionSurface extends StatefulWidget {
  const AttentionSurface({
    super.key,
    required this.active,
    required this.token,
    required this.child,
    this.color = const Color(0xFFD6AE70),
    this.radius = 16,
  });
  final bool active;
  final Object? token;
  final Widget child;
  final Color color;
  final double radius;
  @override
  State<AttentionSurface> createState() => _AttentionSurfaceState();
}

class _AttentionSurfaceState extends State<AttentionSurface>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  void _sync() {
    if (widget.active && !ImmersionPreferences.instance.reduced(context)) {
      _pulse.forward(from: 0);
    } else {
      _pulse.stop();
      _pulse.value = 1;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(AttentionSurface old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active || old.token != widget.token) _sync();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _pulse,
    child: widget.child,
    builder: (context, child) {
      final glow = widget.active
          ? .12 + .16 * (1 - (_pulse.value * 4 % 2 - 1).abs())
          : 0.0;
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(
            color: widget.active
                ? widget.color.withValues(alpha: .65)
                : Colors.transparent,
          ),
          boxShadow: widget.active
              ? [
                  BoxShadow(
                    color: widget.color.withValues(alpha: glow),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: child,
      );
    },
  );
}
