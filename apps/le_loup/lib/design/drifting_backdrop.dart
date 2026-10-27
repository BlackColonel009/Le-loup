import 'package:flutter/material.dart';

/// Seul le décor est animé : les boutons et le texte gardent leur position.
class DriftingBackdrop extends StatefulWidget {
  const DriftingBackdrop({super.key, required this.child});
  final Widget child;
  @override
  State<DriftingBackdrop> createState() => _DriftingBackdropState();
}

class _DriftingBackdropState extends State<DriftingBackdrop>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _drift;
  bool _foreground = true, _allowed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _allowed =
        !MediaQuery.disableAnimationsOf(context) &&
        !MediaQuery.accessibleNavigationOf(context) &&
        TickerMode.valuesOf(context).enabled;
    _sync();
  }

  void _sync() {
    if (_allowed && _foreground) {
      if (!_drift.isAnimating) _drift.repeat(reverse: true);
    } else {
      _drift.stop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: LayoutBuilder(
      builder: (context, size) => AnimatedBuilder(
        animation: _drift,
        child: widget.child,
        builder: (context, image) {
          if (!_allowed) return image!;
          final t = Curves.easeInOutSine.transform(_drift.value);
          return Transform.translate(
            offset: Offset(
              size.maxWidth * .012 * (2 * t - 1),
              size.maxHeight * .008 * (2 * t - 1),
            ),
            child: Transform.scale(scale: 1.06 + .025 * t, child: image),
          );
        },
      ),
    ),
  );
}
