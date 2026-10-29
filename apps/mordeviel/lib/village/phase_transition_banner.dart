import 'dart:async';
import 'package:flutter/material.dart';

/// Root overlay stays visible above the council, actions, and existing dialogs.
class PhaseTransitionNotice {
  OverlayEntry? _entry;
  Map? _transition;
  String _theme = 'classic';
  void update(BuildContext context, Map? transition, String theme) {
    _transition = transition;
    _theme = theme;
    if (transition == null) {
      dispose();
      return;
    }
    if (_entry == null) {
      _entry = OverlayEntry(
        builder: (context) => Positioned(
          top: MediaQuery.paddingOf(context).top + 10,
          left: 16,
          right: 16,
          child: IgnorePointer(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: PhaseTransitionBanner(
                  transition: _transition!,
                  theme: _theme,
                ),
              ),
            ),
          ),
        ),
      );
      Overlay.of(context, rootOverlay: true).insert(_entry!);
    } else {
      _entry!.markNeedsBuild();
    }
  }

  void dispose() {
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }
}

class PhaseTransitionBanner extends StatefulWidget {
  const PhaseTransitionBanner({
    super.key,
    required this.transition,
    required this.theme,
  });
  final Map transition;
  final String theme;
  @override
  State<PhaseTransitionBanner> createState() => _PhaseTransitionBannerState();
}

class _PhaseTransitionBannerState extends State<PhaseTransitionBanner> {
  final _elapsed = Stopwatch();
  Timer? _timer;
  int get _remaining =>
      ((widget.transition['remaining_ms'] as num).toInt() -
              _elapsed.elapsedMilliseconds)
          .clamp(0, 5000);
  void _start() {
    _elapsed
      ..reset()
      ..start();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;
      if (_remaining == 0) timer.cancel();
      setState(() {});
    });
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(covariant PhaseTransitionBanner old) {
    super.didUpdateWidget(old);
    if (!identical(old.transition, widget.transition)) _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _elapsed.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final night = widget.transition['target'] == 'night';
    final seconds = (_remaining / 1000).ceil();
    final color = switch (widget.theme) {
      'horror' => const Color(0xFFE59BB4),
      'intense' => const Color(0xFFF2CE80),
      _ => const Color(0xFFD7DFF6),
    };
    return Semantics(
      liveRegion: true,
      child: Material(
        elevation: 12,
        color: const Color(0xEC111724),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withValues(alpha: .65)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              Icon(
                night ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                color: color,
                size: 24,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  seconds > 0
                      ? '${night ? 'Nuit' : 'Jour'} dans : $seconds seconde${seconds > 1 ? 's' : ''}'
                      : '${night ? 'La nuit tombe' : 'Le jour se lève'}…',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
