import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import '../cards/card_gallery.dart';
import '../cards/classic_role.dart';
import 'ending_data.dart';
import 'game_history.dart';
import '../coins/coin_reward_scene.dart';

Future<void> showVictory(
  BuildContext context, {
  required Map<String, dynamic> game,
  required List players,
  CardAmbience ambience = CardAmbience.classic,
  String continueLabel = 'Voir les rôles et retourner au village',
  Future<void> Function(BuildContext)? onRewardsReady,
  String? matchId,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierLabel: 'Fin de partie',
  pageBuilder: (_, _, _) => VictoryScene(
    game: game,
    players: players,
    ambience: ambience,
    continueLabel: continueLabel,
    onRewardsReady: onRewardsReady,
    matchId: matchId,
  ),
);

class VictoryScene extends StatefulWidget {
  const VictoryScene({
    super.key,
    required this.game,
    required this.players,
    this.ambience = CardAmbience.classic,
    this.continueLabel = 'Voir les rôles et retourner au village',
    this.onRewardsReady,
    this.matchId,
  });
  final Map<String, dynamic> game;
  final List players;
  final CardAmbience ambience;
  final String continueLabel;
  final Future<void> Function(BuildContext)? onRewardsReady;
  final String? matchId;
  @override
  State<VictoryScene> createState() => _VictorySceneState();
}

class _VictorySceneState extends State<VictoryScene>
    with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );
  Timer? _rewardsDelay;
  bool _scheduledRewards = false;
  Map<String, dynamic>? _coins;
  bool _loadingCoins = false, _openingCoins = false;
  String? _coinError;
  @override
  void initState() {
    super.initState();
    if (widget.matchId != null) unawaited(_loadCoins());
  }

  Future<void> _loadCoins() async {
    setState(() => _loadingCoins = true);
    try {
      final reward = await loadMatchCoins(widget.matchId!);
      if (mounted) {
        setState(() {
          _coins = reward;
          _coinError = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _coinError = 'Tes gains restent disponibles dans ta bourse.',
        );
      }
    } finally {
      if (mounted) setState(() => _loadingCoins = false);
    }
  }

  Future<void> _continue() async {
    if (_openingCoins) return;
    setState(() => _openingCoins = true);
    final reward = _coins;
    if (reward != null &&
        reward['eligible'] == true &&
        reward['claimed_at'] == null &&
        (reward['amount'] as int) > 0) {
      await showCoinReward(context, reward);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = 1;
    } else if (_animation.value == 0) {
      _animation.forward();
    }
    if (!_scheduledRewards && widget.onRewardsReady != null) {
      _scheduledRewards = true;
      _rewardsDelay = Timer(
        Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 700 : 2800,
        ),
        () {
          if (mounted && ModalRoute.of(context)?.isCurrent != false) {
            unawaited(widget.onRewardsReady!(context));
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _rewardsDelay?.cancel();
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ending = gameEndings[widget.game['winner']];
    final dark = widget.game['winner'] == 'wolves';
    final accent = dark ? const Color(0xFFB9C4F0) : const Color(0xFFE5C078);
    final ids = (widget.game['winner_ids'] as List? ?? []).toSet();
    final names = widget.players
        .where((p) => ids.contains(p['id']))
        .map((p) => p['nickname'] as String)
        .toList();
    return Scaffold(
      body: TavernBackground(
        dim: .90,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, size) => Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _animation,
                      builder: (_, _) => CustomPaint(
                        painter: _EndingLights(_animation.value, accent, dark),
                      ),
                    ),
                  ),
                ),
                ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  children: [
                    Center(
                      child: Icon(
                        dark ? Icons.nights_stay : Icons.auto_awesome,
                        size: 42,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'PARTIE TERMINÉE',
                      textAlign: TextAlign.center,
                      style: TextStyle(letterSpacing: 4, fontSize: 12),
                    ),
                    const SizedBox(height: 18),
                    AnimatedBuilder(
                      animation: _animation,
                      builder: (_, child) => Opacity(
                        opacity: (.25 + _animation.value * .75).clamp(0, 1),
                        child: Transform.scale(
                          scale:
                              .92 +
                              .08 * Curves.easeOut.transform(_animation.value),
                          child: child,
                        ),
                      ),
                      child: Center(
                        child: SizedBox(
                          height: (size.maxHeight * .40).clamp(140, 310),
                          child: AspectRatio(
                            aspectRatio: .7,
                            child: RoleCardFront(
                              role: configuredRole(ending?.role ?? 'villager'),
                              ambience: widget.ambience,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        ending?.title ?? 'Partie terminée',
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.headlineMedium?.copyWith(color: accent),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      ending?.subtitle ?? 'Merci à tous les joueurs.',
                      textAlign: TextAlign.center,
                    ),
                    if (names.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                          'À l’honneur : ${names.join(', ')}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                      onPressed: () =>
                          showGameHistory(context, widget.game, widget.players),
                      icon: const Icon(Icons.history_edu),
                      label: const Text('Revivre toutes les manches'),
                    ),
                    FilledButton.icon(
                      onPressed: _loadingCoins || _openingCoins
                          ? null
                          : _continue,
                      icon:
                          _coins?['eligible'] == true &&
                              _coins?['claimed_at'] == null
                          ? const ShakingChest()
                          : const Icon(Icons.cottage_outlined),
                      label: Text(
                        _loadingCoins
                            ? 'Préparation de ton coffre…'
                            : _coins?['eligible'] == true &&
                                  _coins?['claimed_at'] == null
                            ? 'Continuer · ouvrir mon coffre'
                            : widget.continueLabel,
                      ),
                    ),
                    if (_coinError != null)
                      TextButton(
                        onPressed: _loadCoins,
                        child: Text('$_coinError Réessayer'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EndingLights extends CustomPainter {
  _EndingLights(this.progress, this.color, this.dark);
  final double progress;
  final Color color;
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < 36; i++) {
      final x = ((i * .6180339) % 1) * size.width;
      final y =
          ((i * .271 + (dark ? progress : -progress) * .18) % 1) * size.height;
      paint.color = color.withValues(
        alpha: (.15 + .35 * math.sin(i + progress * math.pi).abs()),
      );
      canvas.drawCircle(Offset(x, y), 1.3 + i % 3, paint);
    }
    paint.shader = RadialGradient(
      colors: [color.withValues(alpha: .12), Colors.transparent],
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _EndingLights old) => old.progress != progress;
}
