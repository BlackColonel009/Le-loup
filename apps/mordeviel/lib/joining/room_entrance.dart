import 'dart:math' as math;
import 'package:flutter/material.dart';

Future<void> showRoomEntrance(BuildContext context, String theme) =>
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      pageBuilder: (context, _, _) => RoomEntranceScreen(
        theme: theme,
        onComplete: () {
          if (!context.mounted) return;
          final route = ModalRoute.of(context);
          if (route?.isCurrent == true) {
            Navigator.of(context).pop();
          } else if (route != null && route.isActive) {
            Navigator.of(context).removeRoute(route);
          }
        },
      ),
    );

class RoomEntranceScreen extends StatefulWidget {
  const RoomEntranceScreen({
    super.key,
    required this.theme,
    required this.onComplete,
  });
  final String theme;
  final VoidCallback onComplete;
  @override
  State<RoomEntranceScreen> createState() => _RoomEntranceScreenState();
}

class _RoomEntranceScreenState extends State<RoomEntranceScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _time =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2800),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _finish();
      });
  bool _started = false, _finished = false;
  void _finish() {
    if (_finished) return;
    _finished = true;
    _time.stop();
    widget.onComplete();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _time.duration = const Duration(milliseconds: 600);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_finished) _time.forward();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_finished) {
      _time.forward();
    } else {
      _time.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final intense = widget.theme == 'intense',
        horror = widget.theme == 'horror';
    final title = horror
        ? 'Horreur'
        : intense
        ? 'Intense'
        : 'Classique';
    final accent = horror
        ? const Color(0xFFE39BA7)
        : intense
        ? const Color(0xFFBCE9F2)
        : const Color(0xFFD6AE70);
    final line = horror
        ? 'La brume se referme.\nEntre… si tu l’oses.'
        : intense
        ? 'Sous la neige,\nchaque regard cache un secret.'
        : 'Les lanternes s’allument.\nLe village t’attend.';
    return Scaffold(
      backgroundColor: const Color(0xFF0D151C),
      body: AnimatedBuilder(
        animation: _time,
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/backgrounds/portrait.jpg',
              fit: BoxFit.cover,
              excludeFromSemantics: true,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    horror
                        ? const Color(0xEB180F22)
                        : intense
                        ? const Color(0xDE122A3B)
                        : const Color(0xDE1E251F),
                    const Color(0xF5101820),
                  ],
                ),
              ),
            ),
            if (!MediaQuery.disableAnimationsOf(context))
              IgnorePointer(
                child: CustomPaint(
                  painter: _EntranceAtmosphere(
                    _time.value,
                    intense,
                    horror,
                    accent,
                  ),
                ),
              ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                horror
                                    ? Icons.nights_stay_outlined
                                    : intense
                                    ? Icons.ac_unit
                                    : Icons.auto_awesome,
                                color: accent,
                                size: MediaQuery.sizeOf(context).height < 400
                                    ? 48
                                    : 76,
                              ),
                              const SizedBox(height: 25),
                              Text(
                                'PARTIE',
                                style: TextStyle(
                                  letterSpacing: 5,
                                  color: accent,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Cormorant',
                                  fontSize: 43,
                                  color: accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                line,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFF2E8D5),
                                  height: 1.6,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 28),
                              SizedBox(
                                width: 120,
                                child: LinearProgressIndicator(
                                  value: _time.value,
                                  color: accent,
                                  backgroundColor: accent.withValues(
                                    alpha: .15,
                                  ),
                                  minHeight: 2,
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Entrée dans le village…',
                                style: TextStyle(
                                  color: Color(0xFFB5BCBA),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _finish,
                        child: Text('Passer', style: TextStyle(color: accent)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntranceAtmosphere extends CustomPainter {
  _EntranceAtmosphere(this.p, this.intense, this.horror, this.color);
  final double p;
  final bool intense, horror;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (horror) {
      for (var i = 0; i < 4; i++) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(
              size.width * (.2 + i * .24 + math.sin(p * math.pi + i) * .1),
              size.height * (.24 + i * .17),
            ),
            width: size.width * .9,
            height: 65,
          ),
          Paint()
            ..color = const Color(0xFFAAAAAF).withValues(alpha: .035)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 23),
        );
      }
      return;
    }
    for (var i = 0; i < 38; i++) {
      final x = ((i * .317 + math.sin(i + p * 2) * .018) % 1) * size.width;
      final y = ((i * .193 + (intense ? p * .25 : -p * .12)) % 1) * size.height;
      canvas.drawCircle(
        Offset(x, y),
        intense ? 1.2 + i % 3 : .8,
        Paint()..color = color.withValues(alpha: intense ? .35 : .2),
      );
    }
  }

  @override
  bool shouldRepaint(_EntranceAtmosphere old) =>
      old.p != p || old.intense != intense || old.horror != horror;
}
