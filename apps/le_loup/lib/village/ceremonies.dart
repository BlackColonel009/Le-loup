import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../cards/classic_role.dart';
import '../cards/card_gallery.dart';

const sentenceIllustrations = [
  'assets/village/intense/sentences/guillotine.jpg',
  'assets/village/intense/sentences/pilori.jpg',
  'assets/village/intense/sentences/bannissement.jpg',
  'assets/village/intense/sentences/cachot.jpg',
  'assets/village/intense/sentences/echafaud.jpg',
  'assets/village/intense/sentences/exil.jpg',
  'assets/village/intense/sentences/jugement.jpg',
  'assets/village/intense/sentences/gibet.jpg',
];

class SentenceWheel extends StatefulWidget {
  const SentenceWheel({
    super.key,
    required this.game,
    required this.isHost,
    required this.onSpin,
    required this.name,
    this.onContinue,
    this.intense = false,
  });
  final Map<String, dynamic> game;
  final bool isHost;
  final VoidCallback onSpin;
  final String Function(dynamic) name;
  final VoidCallback? onContinue;
  final bool intense;
  @override
  State<SentenceWheel> createState() => _SentenceWheelState();
}

class _SentenceWheelState extends State<SentenceWheel>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4500),
  );
  String? _id;
  void _sync() {
    final sentence = widget.game['sentence'] as Map?;
    if (sentence == null) {
      _id = null;
      _animation.value = 0;
      return;
    }
    if (_id == sentence['id']) return;
    _id = sentence['id'] as String;
    final remaining = (sentence['remaining_ms'] as int).clamp(0, 4500);
    _animation.value = 1 - remaining / 4500;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _animation.value = 1;
      } else {
        _animation.forward();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant SentenceWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.game['vote_result'] as Map?;
    if (result?['eliminated'] == null) return const SizedBox.shrink();
    final sentence = widget.game['sentence'] as Map?;
    final labels = (widget.game['sentence_options'] as List? ?? const [])
        .cast<String>();
    final index = sentence?['index'] as int? ?? 0;
    final targetAngle =
        math.pi * 10 + (math.pi * 2 - (index + .5) * math.pi / 4);
    return Card(
      color: const Color(0xFF292115),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'La sentence de ${widget.name(result!['eliminated'])}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Une mise en scène : le résultat du vote reste inchangé.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: AspectRatio(
                aspectRatio: 1,
                child: AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) => Stack(
                    children: [
                      if (widget.intense)
                        Positioned.fill(
                          child: Image.asset(
                            'assets/village/intense/wheel.png',
                          ),
                        ),
                      Positioned.fill(
                        child: Transform.rotate(
                          angle: sentence == null
                              ? 0
                              : targetAngle *
                                    Curves.easeOutCubic.transform(
                                      _animation.value,
                                    ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (!widget.intense)
                                Image.asset(
                                  'assets/village/wheel.png',
                                  fit: BoxFit.contain,
                                ),
                              if (widget.intense)
                                Padding(
                                  padding: const EdgeInsets.all(36),
                                  child: CustomPaint(
                                    painter: _IntenseWheelDisk(),
                                  ),
                                ),
                              CustomPaint(painter: _WheelLabels(labels)),
                            ],
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.topCenter,
                        child: FractionallySizedBox(
                          widthFactor: .09,
                          child: Image.asset(
                            'assets/village/pointer.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.isHost && sentence == null)
              FilledButton.icon(
                onPressed: widget.onSpin,
                icon: const Icon(Icons.casino_outlined),
                label: const Text('Lancer la roue des sentences'),
              ),
            if (!widget.isHost && sentence == null)
              const Text('Le MDJ peut lancer la roue.'),
            if (sentence != null)
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) => Padding(
                  padding: const EdgeInsets.all(12),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      _animation.isCompleted
                          ? 'Sentence : ${sentence['label']}'
                          : 'Le sort du village tourne…',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ),
              ),
            if (sentence != null && widget.isHost) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: (sentence['remaining_ms'] as int? ?? 0) == 0
                    ? widget.onContinue
                    : null,
                icon: const Icon(Icons.arrow_forward),
                label: Text(
                  (sentence['remaining_ms'] as int? ?? 0) > 0
                      ? 'La roue termine son annonce…'
                      : widget.game['phase'] == 'hunter'
                      ? 'Reprendre le dernier tir du Chasseur'
                      : widget.game['phase'] == 'scapegoat'
                      ? 'Reprendre le choix des électeurs'
                      : widget.game['phase'] == 'ended'
                      ? 'Voir le résultat de la partie'
                      : 'Commencer la nuit suivante',
                ),
              ),
            ],
            if (widget.intense &&
                sentence != null &&
                (sentence['remaining_ms'] as int? ?? 0) == 0 &&
                index >= 0 &&
                index < 8)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Text(
                      'La sentence de ${widget.name(result['eliminated'])} : ${sentence['label']}',
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 280,
                      child: Image.asset(
                        sentenceIllustrations[index],
                        fit: BoxFit.contain,
                        semanticLabel:
                            'Illustration de la sentence ${sentence['label']}',
                      ),
                    ),
                  ],
                ),
              ),
            if (sentence != null && !widget.isHost)
              const Text('Le MDJ poursuit la partie après cette annonce.'),
          ],
        ),
      ),
    );
  }
}

class _IntenseWheelDisk extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < 8; i++) {
      canvas.drawArc(
        rect,
        -math.pi / 2 + i * math.pi / 4,
        math.pi / 4,
        true,
        Paint()
          ..color = i.isEven
              ? const Color(0xFFD3BD91)
              : const Color(0xFF9FAEBA),
      );
      final angle = -math.pi / 2 + i * math.pi / 4;
      canvas.drawLine(
        center,
        center + Offset(math.cos(angle), math.sin(angle)) * radius,
        Paint()
          ..color = const Color(0xFF725628)
          ..strokeWidth = 2,
      );
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFFC9A759)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    canvas.drawCircle(
      center,
      radius * .17,
      Paint()..color = const Color(0xFF344754),
    );
    canvas.drawCircle(
      center,
      radius * .17,
      Paint()
        ..color = const Color(0xFFC9A759)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(covariant _IntenseWheelDisk oldDelegate) => false;
}

class _WheelLabels extends CustomPainter {
  _WheelLabels(this.labels);
  final List<String> labels;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < labels.length && i < 8; i++) {
      final angle = (i + .5) * math.pi / 4;
      final position =
          center +
          Offset(math.sin(angle), -math.cos(angle)) * (size.width * .32);
      final text = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: const Color(0xFF20150B),
            fontSize: size.width * .033,
            fontWeight: FontWeight.bold,
            shadows: const [Shadow(color: Color(0xFFEBDDAD), blurRadius: 3)],
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width * .23);
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(angle);
      text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _WheelLabels oldDelegate) =>
      oldDelegate.labels != labels;
}

Future<void> showElimination(
  BuildContext context, {
  required String name,
  String? role,
  required String cause,
  CardAmbience ambience = CardAmbience.classic,
  bool feminine = false,
  bool cursed = false,
  String? lastWords,
  VoidCallback? onRevealed,
  VoidCallback? onDismissed,
  bool hasNext = false,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierLabel: 'Annonce d’élimination',
  barrierColor: const Color(0xF0080B10),
  pageBuilder: (context, animation, secondaryAnimation) => _DeathCard(
    name: name,
    role: role,
    cause: cause,
    ambience: ambience,
    feminine: feminine,
    cursed: cursed,
    lastWords: lastWords,
    onRevealed: onRevealed,
    onDismissed: onDismissed,
    hasNext: hasNext,
  ),
);

class _DeathCard extends StatefulWidget {
  const _DeathCard({
    required this.name,
    this.role,
    required this.cause,
    required this.ambience,
    required this.feminine,
    required this.cursed,
    this.lastWords,
    this.onRevealed,
    this.onDismissed,
    this.hasNext = false,
  });
  final String? lastWords;
  final VoidCallback? onRevealed, onDismissed;
  final bool hasNext;
  final bool feminine;
  final bool cursed;
  final CardAmbience ambience;
  final String name;
  final String? role;
  final String cause;
  @override
  State<_DeathCard> createState() => _DeathCardState();
}

class _DeathCardState extends State<_DeathCard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _animation = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.cursed ? 2800 : 1800),
  );
  bool _concealed = false;
  bool _spoken = false, _leaving = false;
  double _dragDistance = 0;
  void _revealSpeech() {
    if (_animation.value >= .55 && !_spoken && !_concealed && !_leaving) {
      _spoken = true;
      widget.onRevealed?.call();
    }
  }

  Future<void> _dismiss() async {
    if (_leaving) return;
    setState(() => _leaving = true);
    widget.onDismissed?.call();
    if (!MediaQuery.disableAnimationsOf(context)) {
      await Future<void>.delayed(const Duration(milliseconds: 260));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _animation.addListener(_revealSpeech);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _animation.value = 1;
      } else {
        _animation.forward();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted) {
      setState(() => _concealed = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AnimatedSlide(
      offset: _leaving ? const Offset(0, 1) : Offset.zero,
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 260),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: (_) => _dragDistance = 0,
            onVerticalDragUpdate: (details) =>
                _dragDistance += details.primaryDelta ?? 0,
            onVerticalDragEnd: (details) {
              if (_dragDistance > 56 || (details.primaryVelocity ?? 0) > 180) {
                _dismiss();
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    widget.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    widget.cursed
                        ? 'Les pouvoirs du camp Village sont désactivés.'
                        : widget.cause == 'poison'
                        ? 'Éliminé par une potion'
                        : widget.cause == 'love'
                        ? 'Le chagrin a emporté son destin'
                        : widget.cause == 'white_wolf'
                        ? 'Éliminé pendant la nuit'
                        : widget.cause == 'night'
                        ? 'Éliminé pendant la nuit'
                        : widget.cause == 'hunter'
                        ? 'Dernier tir du Chasseur'
                        : 'Éliminé par le vote',
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: .7,
                        child: AnimatedBuilder(
                          animation: _animation,
                          builder: (context, child) {
                            final flip = ((_animation.value - .1) / .45).clamp(
                              0.0,
                              1.0,
                            );
                            final front =
                                flip > .5 && !_concealed && widget.role != null;
                            return Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, .001)
                                ..rotateY(
                                  (flip > .5 ? flip - 1 : flip) * math.pi,
                                ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  if (front)
                                    RoleCardFront(
                                      role: configuredRole(
                                        widget.role!,
                                        feminine: widget.feminine,
                                      ),
                                      ambience: widget.ambience,
                                    )
                                  else
                                    Image.asset(
                                      widget.ambience == CardAmbience.intense
                                          ? (widget.cause == 'night'
                                                ? 'assets/village/intense/card_clawed.png'
                                                : 'assets/village/intense/card_back.png')
                                          : 'assets/village/card_back.png',
                                      fit: BoxFit.contain,
                                    ),
                                  if (widget.cause != 'curse')
                                    ClipRect(
                                      clipper: _ScratchClipper(
                                        ((_animation.value - .55) / .35).clamp(
                                          0.0,
                                          1.0,
                                        ),
                                      ),
                                      child: Image.asset(
                                        'assets/village/claws.png',
                                        fit: BoxFit.fill,
                                      ),
                                    ),
                                  if (widget.cursed)
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        child: CustomPaint(
                                          painter: _ElderLightning(
                                            _animation.value,
                                            MediaQuery.disableAnimationsOf(
                                              context,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) => Text(
                      _concealed
                          ? 'Carte masquée'
                          : widget.cursed && widget.role == null
                          ? 'L’identité reste cachée, mais la malédiction frappe le Village.'
                          : widget.role == null
                          ? 'Son rôle reste secret selon les règles du salon.'
                          : _animation.value < .55
                          ? 'La carte se révèle…'
                          : 'Rôle : ${configuredRole(widget.role!).name}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (widget.lastWords != null)
                    AnimatedBuilder(
                      animation: _animation,
                      builder: (_, _) => !_concealed && _animation.value >= .55
                          ? ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 80),
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    '« ${widget.lastWords} »',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  const Text(
                    'Glisser vers le bas pour continuer',
                    style: TextStyle(fontSize: 12),
                  ),
                  FilledButton(
                    onPressed: _leaving ? null : _dismiss,
                    child: Text(
                      widget.hasNext
                          ? 'Carte suivante'
                          : 'Retourner au village',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ScratchClipper extends CustomClipper<Rect> {
  _ScratchClipper(this.progress);
  final double progress;
  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * progress, size.height);
  @override
  bool shouldReclip(covariant _ScratchClipper oldClipper) =>
      oldClipper.progress != progress;
}

/// A single soft lightning reveal; no repeated flashing or strobe.
class _ElderLightning extends CustomPainter {
  _ElderLightning(this.progress, this.reduced);
  final double progress;
  final bool reduced;
  @override
  void paint(Canvas canvas, Size size) {
    final strength = reduced
        ? .35
        : math.sin(((progress - .4) / .6).clamp(0, 1) * math.pi);
    if (strength <= 0) return;
    final glow = Paint()
      ..color = Color.fromRGBO(172, 198, 255, strength * .7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    for (final mirrored in [false, true]) {
      final path = Path();
      const points = [
        Offset(.18, .02),
        Offset(.38, .22),
        Offset(.24, .37),
        Offset(.54, .53),
        Offset(.43, .68),
        Offset(.73, .98),
      ];
      for (var i = 0; i < points.length; i++) {
        final p = points[i];
        final x = (mirrored ? 1 - p.dx : p.dx) * size.width;
        if (i == 0) {
          path.moveTo(x, p.dy * size.height);
        } else {
          path.lineTo(x, p.dy * size.height);
        }
      }
      canvas.drawPath(
        path,
        glow..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawPath(path, glow..maskFilter = null);
    }
  }

  @override
  bool shouldRepaint(covariant _ElderLightning old) =>
      old.progress != progress || old.reduced != reduced;
}
