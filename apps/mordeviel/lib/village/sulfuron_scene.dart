import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../audio/classic_audio.dart';
import '../cards/card_gallery.dart';
import '../cards/classic_role.dart';

export 'burning_card.dart' show BurningCard;

/// Public announcements contain the announced card only, never the caster.
Future<void> showSulfuronScene(
  BuildContext context, {
  required Map<String, dynamic> event,
  required String playerName,
  required CardAmbience ambience,
  bool voteUsed = false,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierLabel: 'Le piège de Sulfuron',
  barrierColor: const Color(0xED080608),
  pageBuilder: (_, _, _) =>
      _SulfuronScene(event, playerName, ambience, voteUsed),
);

class _SulfuronScene extends StatefulWidget {
  const _SulfuronScene(this.event, this.name, this.ambience, this.voteUsed);
  final Map<String, dynamic> event;
  final String name;
  final CardAmbience ambience;
  final bool voteUsed;
  @override
  State<_SulfuronScene> createState() => _SulfuronSceneState();
}

class _SulfuronSceneState extends State<_SulfuronScene>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4800),
  );
  bool _concealed = false;
  bool _announced = false;
  bool get _revelation => widget.event['kind'] == 'revelation';
  bool get _gain => widget.event['kind'] == 'soul_gained';
  bool get _bluff => widget.event['power'] == 'bluff';
  String get _title => _revelation
      ? 'Sulfuron sème le doute…'
      : _gain
      ? '+1 vie volée'
      : 'Le Fourbe revient !';
  @override
  void initState() {
    super.initState();
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _concealed = lifecycle != null && lifecycle != AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_concealed) _reveal();
    });
  }

  void _reveal() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.value = 1;
    } else if (!_motion.isCompleted) {
      _motion.forward();
    }
    if (!_announced) {
      _announced = true;
      ClassicAudio.instance.sulfuronSpeech(
        _revelation ? (_bluff ? 'bluff' : 'reveal') : 'revive',
        private: !_revelation && widget.event['kind'] != 'resurrection',
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed || _concealed) return;
    _motion.stop();
    setState(() => _concealed = true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ClassicAudio.instance.stopDeathSpeech();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_concealed) {
      return AlertDialog(
        title: const Text('Carte masquée'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continuer'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _concealed = false);
              _reveal();
            },
            child: const Text('Afficher la carte'),
          ),
        ],
      );
    }
    final role =
        widget.event['role'] as String? ??
        (_revelation || widget.event['kind'] == 'resurrection'
            ? null
            : 'sulfuron');
    final lives = widget.event['lives'];
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: EdgeInsets.all(
                MediaQuery.sizeOf(context).width >
                        MediaQuery.sizeOf(context).height
                    ? 10
                    : 24,
              ),
              child: Column(
                children: [
                  if (!_revelation)
                    Text(
                      _title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(color: const Color(0xFFFFC76B)),
                    ),
                  if (_revelation && role != null)
                    AnimatedBuilder(
                      animation: _motion,
                      builder: (_, _) => RevelationParchment(
                        progress: _motion.value,
                        text:
                            '${widget.name} est ${['seer', 'witch', 'little_girl'].contains(role)
                                ? 'une'
                                : role == 'sisters'
                                ? 'les'
                                : 'un'} ${configuredRole(role).name}',
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    _revelation ? widget.name : 'Sulfuron · Le Fourbe',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _motion,
                      builder: (_, _) {
                        final p = Curves.easeOutCubic.transform(_motion.value);
                        return Opacity(
                          opacity: p,
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, .001)
                              ..rotateY((1 - p) * math.pi * .7)
                              ..scaleByDouble(
                                .85 + .15 * p,
                                .85 + .15 * p,
                                1,
                                1,
                              ),
                            child: Container(
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF881B).withValues(
                                      alpha: .25 * math.sin(math.pi * p),
                                    ),
                                    blurRadius: 60,
                                  ),
                                ],
                              ),
                              child: role == null
                                  ? const Icon(
                                      Icons.local_fire_department,
                                      size: 150,
                                      color: Colors.amber,
                                    )
                                  : AspectRatio(
                                      aspectRatio: .7,
                                      child: RoleCardFront(
                                        role: configuredRole(
                                          role,
                                          edition: widget.ambience.asset,
                                        ),
                                        ambience: widget.ambience,
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_revelation) ...[
                    Text(
                      widget.event['text'] as String? ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _bluff
                          ? 'Annonce de Sulfuron · cette carte peut être fausse.'
                          : 'Carte révélée par Sulfuron.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFFFC76B)),
                    ),
                  ] else ...[
                    if (lives is int)
                      Text(
                        '$lives vie${lives > 1 ? 's' : ''} en réserve',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    Text(
                      _gain
                          ? 'La cible révélée a été condamnée. Une vie vous ramènera après une attaque de la meute.'
                          : widget.event['cause'] == 'vote'
                          ? 'La première sentence n’a pas suffi. Un second vote sera définitif.'
                          : 'Une vie volée vous a ramené après l’attaque de la meute.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.ambience == CardAmbience.classic
                          ? 'Le vote, le poison, le Chasseur et le chagrin restent mortels.'
                          : '${widget.voteUsed ? 'Protection au vote déjà consommée.' : 'Une vie peut aussi déjouer votre première condamnation.'}${widget.ambience == CardAmbience.horror ? ' Après cette résurrection au vote, marquez un accusateur dans Actions.' : ''}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Continuer'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RevelationParchment extends StatelessWidget {
  const RevelationParchment({
    super.key,
    required this.progress,
    required this.text,
  });
  final double progress;
  final String text;
  @override
  Widget build(BuildContext context) {
    final opening = (progress / .28).clamp(0.0, 1.0);
    final compact =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    final writing = ((progress - .28) / .65).clamp(0.0, 1.0);
    final letters = text.characters;
    final shown = letters.take((letters.length * writing).ceil()).toString();
    return ClipRect(
      child: Align(
        heightFactor: Curves.easeOutCubic.transform(opening),
        child: Container(
          width: double.infinity,
          margin: EdgeInsets.symmetric(vertical: compact ? 4 : 10),
          padding: EdgeInsets.all(compact ? 8 : 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFF9E6632),
                Color(0xFFF3DCAC),
                Color(0xFFE1BB7A),
                Color(0xFF9E6632),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF6D421E), width: 3),
          ),
          child: Column(
            children: [
              Text(
                'Sulfuron révèle un joueur',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cormorant',
                  fontWeight: FontWeight.bold,
                  fontSize: compact ? 19 : 25,
                  color: Color(0xFF3A1E0C),
                ),
              ),
              const SizedBox(height: 8),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: writing > 0 && writing < 1
                          ? shown.characters
                                .take(math.max(0, shown.characters.length - 1))
                                .toString()
                          : shown,
                    ),
                    if (writing > 0 && writing < 1 && shown.isNotEmpty)
                      TextSpan(
                        text: shown.characters.last,
                        style: const TextStyle(
                          color: Color(0xFFFFE5A3),
                          shadows: [
                            Shadow(color: Colors.deepOrange, blurRadius: 20),
                            Shadow(color: Colors.orange, blurRadius: 8),
                          ],
                        ),
                      ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 17 : 22,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF622306),
                  shadows: writing > 0 && writing < 1
                      ? [
                          Shadow(
                            color: Colors.orangeAccent,
                            blurRadius: 8 + 6 * math.sin(progress * 80).abs(),
                          ),
                          const Shadow(color: Colors.red, blurRadius: 18),
                        ]
                      : [],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The previous rising-fire effect, retained with the supplied animated GIF.
class BottomUpGifBurningCard extends StatelessWidget {
  const BottomUpGifBurningCard({
    super.key,
    required this.progress,
    required this.child,
  });

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'La carte brûle du bas vers le haut',
    child: Stack(
      fit: StackFit.expand,
      children: [
        ClipPath(clipper: _BurnClipper(progress), child: child),
        if (progress > .03 && progress < 1)
          IgnorePointer(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                final fireWidth = size.width * 1.08;
                final fireHeight = size.height * .52;
                final edge = _edge(size.width / 2, size, progress);
                final opacity = math.sin(math.pi * progress).clamp(0.0, 1.0);
                return Stack(
                  children: [
                    Positioned(
                      left: (size.width - fireWidth) / 2,
                      top: edge - fireHeight * .76,
                      width: fireWidth,
                      height: fireHeight,
                      child: Opacity(
                        opacity: opacity,
                        child: Image.asset(
                          'assets/village/fire.gif',
                          alignment: Alignment.bottomCenter,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          filterQuality: FilterQuality.medium,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        IgnorePointer(child: CustomPaint(painter: _BurnPainter(progress))),
      ],
    ),
  );
}

double _edge(double x, Size s, double p) {
  final across = x / s.width;
  final burn = math.sin(math.pi * p);
  final faster = math.sin(across * 13 + p * 4) + .46 * math.cos(across * 29);
  final torn = math.sin(across * 62 + p * 9);
  return s.height * (1.08 - 1.2 * p + (.056 * faster + .008 * torn) * burn);
}

Path _front(Size s, double p, [double shift = 0]) {
  final path = Path()..moveTo(0, _edge(0, s, p) + shift);
  for (double x = 3; x < s.width + 3; x += 3) {
    path.lineTo(x, _edge(x, s, p) + shift);
  }
  return path;
}

void _drawFallingAsh(Canvas canvas, Size size, double progress) {
  for (var i = 0; i < 22; i++) {
    final seed = i.toDouble();
    final age = (progress * 2.6 + seed * .173) % 1;
    final originX = ((seed * 47.17 + 13) % 100) / 100 * size.width;
    final drift = math.sin(age * math.pi * 2 + seed * 2.7) * size.width * .018;
    final x = originX + drift + age * size.width * .035;
    final y = _edge(originX, size, progress) + age * size.height * .28;
    final opacity = (1 - age) * math.sin(math.pi * progress) * .8;
    final width = size.shortestSide * (.008 + (seed % 3) * .002);
    final height = width * (1.2 + (seed % 4) * .35);
    final rotation = age * math.pi * 2 + seed * 1.9;
    final shard = Path()
      ..moveTo(-width * .5, -height * .35)
      ..lineTo(width * .32, -height * .5)
      ..lineTo(width * .5, height * .18)
      ..lineTo(-width * .12, height * .5)
      ..close();

    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(rotation);
    canvas.drawPath(
      shard,
      Paint()
        ..color = Color.lerp(
          const Color(0xFF3A3028),
          const Color(0xFFB05A25),
          (seed % 5) / 5,
        )!.withValues(alpha: opacity),
    );
    canvas.restore();
  }
}

class _BurnClipper extends CustomClipper<Path> {
  _BurnClipper(this.p);
  final double p;
  @override
  Path getClip(Size s) => p >= 1
      ? Path()
      : (_front(s, p)
          ..lineTo(s.width, 0)
          ..lineTo(0, 0)
          ..close());
  @override
  bool shouldReclip(_BurnClipper old) => old.p != p;
}

class _BurnPainter extends CustomPainter {
  _BurnPainter(this.p);
  final double p;
  @override
  void paint(Canvas c, Size s) {
    if (p <= .03 || p >= 1) return;
    final edge = _front(s, p);
    c.save();
    c.clipRect(Offset.zero & s);
    c.drawPath(
      _front(s, p, -6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..color = const Color(0xFF20110B),
    );
    c.drawPath(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..color = const Color(0x95F45B1A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    c.drawPath(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = const LinearGradient(
          colors: [
            Color(0x25FF7023),
            Color(0xCDFFD19B),
            Color(0x29FF7023),
            Color(0xAFFF9A53),
            Color(0x39CB4C13),
          ],
        ).createShader(Offset.zero & s),
    );
    _drawFallingAsh(c, s, p);
    for (var i = 0; i < 42; i++) {
      final x = ((i * 73.91) % 100) / 100 * s.width;
      final phase = (p * 3.4 + i * .173) % 1;
      final y = _edge(x, s, p) - phase * s.height * .32;
      final opacity = (1 - phase) * math.sin(math.pi * p);
      c.drawCircle(
        Offset(x + math.sin(i + p * 12) * 9, y),
        3 + phase * 13,
        Paint()
          ..color = Colors.grey.withValues(alpha: opacity * .12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      c.drawCircle(
        Offset(x + math.sin(i + p * 12) * 9, y),
        1.2 + 1.6 * (1 - phase),
        Paint()
          ..color = Color.lerp(
            const Color(0xFFFFF4B5),
            const Color(0xFFF05B12),
            phase,
          )!.withValues(alpha: opacity),
      );
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_BurnPainter old) => old.p != p;
}
