import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../audio/classic_audio.dart';
import '../cards/card_gallery.dart';
import '../cards/classic_role.dart';

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
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4800),
  );
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      MediaQuery.disableAnimationsOf(context)
          ? _motion.value = 1
          : _motion.forward();
      ClassicAudio.instance.sulfuronSpeech(
        _revelation ? (_bluff ? 'bluff' : 'reveal') : 'revive',
        private: !_revelation && widget.event['kind'] != 'resurrection',
      );
    });
  }

  @override
  void dispose() {
    ClassicAudio.instance.stopDeathSpeech();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

/// A ragged advancing combustion front with ember cores, char and rising ash.
class BurningCard extends StatelessWidget {
  const BurningCard({super.key, required this.progress, required this.child});
  final double progress;
  final Widget child;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'La carte brûle et devient cendre',
    child: Stack(
      fit: StackFit.expand,
      children: [
        ClipPath(clipper: _BurnClipper(progress), child: child),
        IgnorePointer(child: CustomPaint(painter: _BurnPainter(progress))),
      ],
    ),
  );
}

double _edge(double x, Size s, double p) =>
    s.height * (1.08 - 1.2 * p) +
    (math.sin(x * .083 + 2) * 8 +
            math.sin(x * .23) * 3 +
            math.sin(x * .041) * 12) *
        math.sin(math.pi * p);
Path _front(Size s, double p, [double shift = 0]) {
  final path = Path()..moveTo(0, _edge(0, s, p) + shift);
  for (double x = 3; x < s.width + 3; x += 3) {
    path.lineTo(x, _edge(x, s, p) + shift);
  }
  return path;
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
        ..strokeWidth = 12
        ..color = const Color(0xFFFF5E08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    c.drawPath(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFFFD18B),
    );
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
      if (i.isEven) {
        final base = _edge(x, s, p);
        final flame = Path()
          ..moveTo(x - 6, base + 5)
          ..quadraticBezierTo(
            x - 10,
            base - 12,
            x + math.sin(i + p * 30) * 6,
            base - 18 - 22 * phase,
          )
          ..quadraticBezierTo(x + 12, base - 8, x + 6, base + 5)
          ..close();
        c.drawPath(
          flame,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                const Color(0xFFFFCC68),
                const Color(0xFFFF6810).withValues(alpha: .6),
                Colors.transparent,
              ],
            ).createShader(Rect.fromLTWH(x - 12, base - 45, 24, 50)),
        );
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_BurnPainter old) => old.p != p;
}
