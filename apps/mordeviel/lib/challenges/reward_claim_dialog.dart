import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'challenge_card.dart';
import 'challenge_sounds.dart';
import '../social/social_api.dart';
import '../social/social_service.dart';
import '../profile/avatar_border.dart';

enum RewardChestTier { classic, epic, premium }

Color rewardChestLight(RewardChestTier tier) => switch (tier) {
  RewardChestTier.classic => const Color(0xFFFFD995),
  RewardChestTier.epic => const Color(0xFFD1A1FF),
  RewardChestTier.premium => const Color(0xFF79EBF4),
};

/// A batch uses the most prestigious cosmetic it contains.
RewardChestTier rewardChestTier(Iterable<Map> rewards) {
  var tier = RewardChestTier.classic;
  for (final reward in rewards) {
    if (reward['kind'] != 'border') continue;
    final border = avatarBorder(reward['id'] as String?);
    if (border == null) continue;
    if (border['effect'] != 'artwork') return RewardChestTier.premium;
    tier = RewardChestTier.epic;
  }
  return tier;
}

/// Used on the victory screen; a postponed gift remains in the player's carnet.
Future<bool> presentPendingChallengeRewards(BuildContext context) async {
  try {
    final data = await SocialApi.instance.request('/challenges/me');
    if (!context.mounted || ModalRoute.of(context)?.isCurrent == false) {
      return false;
    }
    final pending = (data['pending_challenges'] as List? ?? []).cast<Map>();
    if (pending.isEmpty) return false;
    await showRewardClaimDialog(
      context,
      challenges: pending,
      claim: (ids) => SocialApi.instance.request(
        '/challenges/claim',
        method: 'POST',
        body: {'challenge_ids': ids},
      ),
      onClaimed: (result) => SocialService.instance.updateChallengeRewards(
        result['pending_count'] as int? ?? 0,
        forUser: result['user_id'] as int?,
      ),
    );
    return true;
  } catch (_) {
    // The carnet offers a retry; the victory scene always remains usable.
    return false;
  }
}

typedef RewardClaimRequest =
    Future<Map<String, dynamic>> Function(List<String> ids);

Future<void> showRewardClaimDialog(
  BuildContext context, {
  required List<Map> challenges,
  required RewardClaimRequest claim,
  required void Function(Map<String, dynamic>) onClaimed,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierLabel: 'Récompenses de défis',
  barrierColor: Colors.black.withValues(alpha: .86),
  transitionDuration: MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 320),
  transitionBuilder: (_, animation, _, child) => FadeTransition(
    opacity: animation,
    child: ScaleTransition(
      scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
      child: child,
    ),
  ),
  pageBuilder: (_, _, _) => RewardClaimDialog(
    challenges: challenges,
    claim: claim,
    onClaimed: onClaimed,
  ),
);

class RewardClaimDialog extends StatefulWidget {
  const RewardClaimDialog({
    super.key,
    required this.challenges,
    required this.claim,
    required this.onClaimed,
  });
  final List<Map> challenges;
  final RewardClaimRequest claim;
  final void Function(Map<String, dynamic>) onClaimed;
  @override
  State<RewardClaimDialog> createState() => _RewardClaimDialogState();
}

class _RewardClaimDialogState extends State<RewardClaimDialog>
    with TickerProviderStateMixin {
  late final _shine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final _opening = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  );
  bool _reduced = false, _celebrated = false, _busy = false, _received = false;
  bool _revealed = false;
  String? _error;
  List<Map> get _rewards => widget.challenges
      .expand((c) => (c['rewards'] as List? ?? []).cast<Map>())
      .toList();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced) {
      _shine.stop();
      if (_received && !_revealed) {
        _opening.value = 1;
        _revealed = true;
      }
    } else if (!_shine.isAnimating) {
      _shine.repeat();
    }
    if (!_celebrated) {
      _celebrated = true;
      ChallengeSounds.play(completed: true);
    }
  }

  @override
  void dispose() {
    _shine.dispose();
    _opening.dispose();
    super.dispose();
  }

  Future<void> _claim() async {
    if (_busy || _received) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await widget.claim(
        widget.challenges.map((c) => c['id'] as String).toList(),
      );
      // Apply the confirmed server result even if the route was removed.
      widget.onClaimed(data);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _received = true;
      });
      ChallengeSounds.play(completed: true);
      if (_reduced) {
        _opening.value = 1;
        setState(() => _revealed = true);
      } else {
        _opening.forward().whenCompleteOrCancel(() {
          if (mounted) setState(() => _revealed = true);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.toString();
        });
      }
    }
  }

  Widget _actions() {
    final count = _rewards.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFFFB7A8)),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: challengeGold,
                foregroundColor: const Color(0xFF20170C),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 17,
                ),
                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onPressed: _busy
                  ? null
                  : _received
                  ? () {
                      if (!_revealed) {
                        _opening.value = 1;
                        setState(() => _revealed = true);
                      } else {
                        Navigator.pop(context);
                      }
                    }
                  : _claim,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_received ? Icons.check : Icons.redeem),
              label: Text(
                _busy
                    ? 'Récupération…'
                    : _received
                    ? _revealed
                          ? 'Super, continuer !'
                          : 'Passer l’animation'
                    : count == 1
                    ? 'Réclamer ma récompense'
                    : 'Réclamer mes $count récompenses',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (!_received)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text(
                  'Plus tard · mes cadeaux restent disponibles',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _rewards.length;
    return PopScope(
      canPop: !_busy,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Material(
                color: const Color(0xFF101923),
                borderRadius: BorderRadius.circular(30),
                clipBehavior: Clip.antiAlias,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: challengeGold.withValues(alpha: .75),
                      width: 1.5,
                    ),
                    gradient: const RadialGradient(
                      center: Alignment.topCenter,
                      radius: 1.15,
                      colors: [
                        Color(0xFF3D3430),
                        Color(0xFF121C27),
                        Color(0xFF0B121A),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: challengeGold.withValues(alpha: .14),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Text(
                                    _received
                                        ? 'RÉCOMPENSES RÉCUPÉRÉES'
                                        : widget.challenges.length == 1
                                        ? 'DÉFI ACCOMPLI !'
                                        : '${widget.challenges.length} DÉFIS ACCOMPLIS !',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: challengeGold,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.6,
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height:
                                      MediaQuery.sizeOf(context).height < 600
                                      ? 116
                                      : 172,
                                  width: double.infinity,
                                  child: AnimatedBuilder(
                                    animation: Listenable.merge([
                                      _shine,
                                      _opening,
                                    ]),
                                    builder: (_, _) => CustomPaint(
                                      painter: _RewardChest(
                                        _shine.value,
                                        _opening.value,
                                        _received,
                                        _reduced,
                                        rewardChestTier(_rewards),
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  _received
                                      ? _revealed
                                            ? 'Ces trésors sont à vous !'
                                            : 'Le coffre s’ouvre…'
                                      : switch (rewardChestTier(_rewards)) {
                                          RewardChestTier.classic =>
                                            'Un coffre classique vous attend',
                                          RewardChestTier.epic =>
                                            'Un coffre épique vous attend',
                                          RewardChestTier.premium =>
                                            'Un coffre premium vous attend',
                                        },
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: const Color(0xFFFFE5AF),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _received
                                      ? _revealed
                                            ? 'Cadeaux conservés dans votre compte. Retrouvez portraits et bordures dans votre profil, et stickers dans les discussions.'
                                            : 'Vos cadeaux sont récupérés. Place à la découverte !'
                                      : '$count récompense${count > 1 ? 's' : ''} vous attend${count > 1 ? 'ent' : ''}. Réclamez votre butin !',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFD6D1C8),
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                for (final challenge
                                    in (_received && !_revealed
                                        ? <Map>[]
                                        : widget.challenges))
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: .23,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: challengeGold.withValues(
                                            alpha: .20,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            challenge['title'] as String,
                                            style: const TextStyle(
                                              color: challengeGold,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          for (final reward
                                              in (challenge['rewards'] as List)
                                                  .cast<Map>())
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 3,
                                                  ),
                                              child: Row(
                                                children: [
                                                  ChallengeReward(
                                                    reward: reward,
                                                    size: 42,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          reward['title']
                                                              as String,
                                                          style:
                                                              const TextStyle(
                                                                color: Color(
                                                                  0xFFFFEED3,
                                                                ),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                        Text(
                                                          switch (reward['kind']) {
                                                            'avatar' =>
                                                              'Portrait de profil',
                                                            'avatar_choice' =>
                                                              'Un portrait à choisir après la récupération',
                                                            'border' =>
                                                              'Bordure de profil',
                                                            _ =>
                                                              'Sticker de discussion',
                                                          },
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .white54,
                                                                fontSize: 11,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Icon(
                                                    _received
                                                        ? Icons.check_circle
                                                        : Icons.card_giftcard,
                                                    color: _received
                                                        ? const Color(
                                                            0xFF8DDCB1,
                                                          )
                                                        : challengeGold,
                                                    size: 20,
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      _actions(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A physical lid, emerging light and a burst of stars, drawn without assets.
class _RewardChest extends CustomPainter {
  _RewardChest(
    this.shine,
    this.opening,
    this.received,
    this.reduced,
    this.tier,
  );
  final RewardChestTier tier;
  final double shine, opening;
  final bool received, reduced;
  @override
  void paint(Canvas canvas, Size size) {
    final premium = tier == RewardChestTier.premium;
    final epic = tier == RewardChestTier.epic;
    final light = rewardChestLight(tier);
    final challengeGold = premium
        ? const Color(0xFFFFD779)
        : epic
        ? const Color(0xFFD1B1FF)
        : const Color(0xFFE5C385);
    // Build pressure first, then release the lid. No random values between frames.
    final reveal = Curves.easeOutBack.transform(
      ((opening - .46) / .54).clamp(0.0, 1.0),
    );
    final pressure = received
        ? math.sin((opening / .48).clamp(0.0, 1.0) * math.pi)
        : 0.35;
    final clock = received ? opening * 8 : shine * 2;
    final shake = reduced ? 0.0 : math.sin(clock * math.pi * 12) * pressure;
    final center = Offset(size.width / 2, size.height * .56);
    final scale = math.min(size.width / 270, size.height / 145);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);
    if (tier != RewardChestTier.classic) {
      // Premium has an orbiting seal; epic has a still, faceted rune halo.
      canvas.save();
      canvas.translate(0, -12);
      canvas.rotate(premium && !reduced ? shine * math.pi * 2 : 0);
      final rune = Paint()
        ..color = challengeGold.withValues(alpha: .35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      for (final radius in [65.0, 73.0, 86.0]) {
        canvas.drawCircle(Offset.zero, radius, rune);
      }
      for (var i = 0; i < 48; i++) {
        final angle = i * math.pi / 24;
        canvas.drawLine(
          Offset(math.cos(angle) * 78, math.sin(angle) * 78),
          Offset(
            math.cos(angle) * (i % 4 == 0 ? 85 : 81),
            math.sin(angle) * (i % 4 == 0 ? 85 : 81),
          ),
          rune,
        );
      }
      // Interlaced triangles, planetary sigils and small engraved glyphs.
      for (var triangle = 0; triangle < 2; triangle++) {
        final path = Path();
        for (var vertex = 0; vertex < 3; vertex++) {
          final a =
              -math.pi / 2 + triangle * math.pi + vertex * math.pi * 2 / 3;
          final point = Offset(math.cos(a) * 64, math.sin(a) * 64);
          if (vertex == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        canvas.drawPath(path..close(), rune);
      }
      for (var i = 0; i < 8; i++) {
        canvas.save();
        canvas.rotate(i * math.pi / 4);
        canvas.translate(0, -70);
        canvas.drawCircle(Offset.zero, 2.5, rune);
        canvas.drawLine(const Offset(0, 2.5), const Offset(0, 7), rune);
        canvas.drawLine(const Offset(-2.5, 5), const Offset(2.5, 5), rune);
        canvas.restore();
      }
      if (premium) {
        canvas.drawCircle(Offset.zero, 76, rune);
        canvas.drawCircle(Offset.zero, 82, rune);
      }
      final seal = Path();
      for (var i = 0; i < 8; i++) {
        final angle = i * math.pi / 4;
        final point = Offset(math.cos(angle) * 77, math.sin(angle) * 77);
        if (i == 0) {
          seal.moveTo(point.dx, point.dy);
        } else {
          seal.lineTo(point.dx, point.dy);
        }
        _star(
          canvas,
          point,
          premium ? 4 : 2.5,
          Paint()..color = challengeGold.withValues(alpha: .8),
        );
      }
      canvas.drawPath(seal..close(), rune);
      canvas.restore();
    }
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          light.withValues(alpha: .35 + opening * .3),
          Colors.transparent,
        ],
      ).createShader(const Rect.fromLTWH(-112, -112, 224, 224));
    canvas.drawCircle(Offset.zero, 112, glow);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6 + (reduced ? 0 : shine * math.pi / 8);
      final p = Paint()..color = light.withValues(alpha: .07 + opening * .13);
      canvas.drawPath(
        Path()
          ..moveTo(math.cos(a) * 24, math.sin(a) * 24)
          ..lineTo(math.cos(a - .045) * 105, math.sin(a - .045) * 105)
          ..lineTo(math.cos(a + .045) * 105, math.sin(a + .045) * 105)
          ..close(),
        p,
      );
    }
    if (received && reveal > 0) {
      for (var i = 0; i < 32; i++) {
        final angle = i * 2.39996;
        final travel = Curves.easeOutCubic.transform(opening);
        final distance = 20 + travel * (48 + i % 7 * 9);
        final point = Offset(
          math.cos(angle) * distance,
          math.sin(angle) * distance * .68 - 16 - travel * 20,
        );
        final color = [
          challengeGold,
          const Color(0xFF8CDECA),
          const Color(0xFFEDAADE),
          light,
        ][i % 4];
        final p = Paint()
          ..color = color.withValues(
            alpha: reduced ? .7 : (1 - opening * .45).clamp(0, 1),
          );
        _star(canvas, point, 2.5 + i % 3, p);
      }
    } else {
      for (var i = 0; i < 10; i++) {
        final angle = i * 2.39996;
        final r = 58 + (i % 3) * 15;
        final p = Paint()
          ..color = challengeGold.withValues(
            alpha: .3 + .5 * (.5 + .5 * math.sin(i + shine * 2 * math.pi)),
          );
        _star(
          canvas,
          Offset(math.cos(angle) * r, math.sin(angle) * r * .65 - 5),
          2.8,
          p,
        );
      }
    }
    final bounce = reduced ? 0.0 : -shake.abs() * 5;
    canvas.translate(0, bounce);
    canvas.drawOval(
      const Rect.fromLTWH(-56, 39, 112, 12),
      Paint()
        ..color = Colors.black.withValues(alpha: .35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.translate(shake * 3, 0);
    canvas.rotate(shake * .045);
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-46, -6, 92, 49),
      const Radius.circular(7),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: premium
              ? [const Color(0xFF244B67), const Color(0xFF0C1A32)]
              : epic
              ? [const Color(0xFF644780), const Color(0xFF251932)]
              : [const Color(0xFFB07131), const Color(0xFF442915)],
        ).createShader(body.outerRect),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = challengeGold,
    );
    // Individual oak planks and restrained, hand-cut wood grain.
    canvas.save();
    canvas.clipRRect(body);
    for (var y = 6.0; y < 43; y += 12) {
      canvas.drawLine(
        Offset(-45, y),
        Offset(45, y),
        Paint()
          ..color = const Color(0xFF301B10)
          ..strokeWidth = 1.5,
      );
      for (var i = 0; i < 3; i++) {
        final x = -39.0 + i * 29;
        canvas.drawArc(
          Rect.fromLTWH(x, y + 3, 23, 5),
          0,
          math.pi,
          false,
          Paint()
            ..color = const Color(0xFFDBA25B).withValues(alpha: .25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = .7,
        );
      }
    }
    canvas.restore();
    for (final x in [-29.0, 23.0]) {
      canvas.drawRect(
        Rect.fromLTWH(x, -5, 6, 47),
        Paint()..color = challengeGold,
      );
      for (final y in [1.0, 20.0, 36.0]) {
        canvas.drawCircle(
          Offset(x + 3, y),
          1.7,
          Paint()..color = const Color(0xFF624628),
        );
        canvas.drawCircle(
          Offset(x + 2.6, y - .4),
          .6,
          Paint()..color = const Color(0xFFFFE9B6),
        );
      }
    }
    if (reveal > 0) {
      final mouth = Rect.fromLTWH(-43, -12, 86, 15);
      canvas.drawOval(mouth, Paint()..color = const Color(0xFF20120D));
      canvas.drawOval(
        mouth.deflate(2),
        Paint()
          ..color = light.withValues(alpha: reveal.clamp(0, 1))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawPath(
        Path()
          ..moveTo(-37, -5)
          ..lineTo(-70, -100)
          ..lineTo(70, -100)
          ..lineTo(37, -5)
          ..close(),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              light.withValues(alpha: .65 * reveal.clamp(0, 1)),
              Colors.transparent,
            ],
          ).createShader(const Rect.fromLTWH(-70, -100, 140, 100)),
      );
    }
    canvas.save();
    final rattle = reduced ? 0.0 : shake.abs() * 3;
    canvas.translate(0, -reveal * 48 - rattle);
    canvas.rotate(-reveal * .22 + shake * .025);
    final lid = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-49, -29, 98, 29),
      const Radius.circular(9),
    );
    canvas.drawRRect(
      lid,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: premium
              ? [const Color(0xFF407D91), const Color(0xFF11263E)]
              : epic
              ? [const Color(0xFF9A75B6), const Color(0xFF3C2855)]
              : [const Color(0xFFEECD8C), const Color(0xFF885025)],
        ).createShader(lid.outerRect),
    );
    canvas.drawRRect(
      lid,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFFE7B4),
    );
    for (final x in [-31.0, 22.0]) {
      canvas.drawRect(
        Rect.fromLTWH(x, -28, 9, 27),
        Paint()..color = const Color(0xFFD4B575),
      );
      for (final y in [-23.0, -6.0]) {
        canvas.drawCircle(
          Offset(x + 4.5, y),
          1.7,
          Paint()..color = const Color(0xFF654B2C),
        );
      }
    }
    canvas.restore();
    if (tier != RewardChestTier.classic) {
      // Forged corner plates and an inset amethyst / celestial sapphire.
      final engraving = Paint()
        ..color = challengeGold.withValues(alpha: .8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      for (final side in [-1.0, 1.0]) {
        // Scrollwork brackets echo medieval illuminated manuscripts.
        canvas.drawPath(
          Path()
            ..moveTo(side * 12, 19)
            ..cubicTo(side * 22, 4, side * 39, 10, side * 34, 19)
            ..cubicTo(side * 29, 27, side * 21, 17, side * 29, 15),
          engraving,
        );
        canvas.drawPath(
          Path()
            ..moveTo(side * 12, 36)
            ..cubicTo(side * 22, 44, side * 37, 36, side * 30, 30),
          engraving,
        );
        canvas.drawCircle(Offset(side * 39, 21), 2, Paint()..color = light);
      }
      if (premium) {
        canvas.drawPath(
          Path()
            ..moveTo(-19, -12)
            ..lineTo(-22, -23)
            ..lineTo(-10, -18)
            ..lineTo(0, -30)
            ..lineTo(10, -18)
            ..lineTo(22, -23)
            ..lineTo(19, -12)
            ..close(),
          Paint()..color = challengeGold,
        );
        canvas.drawCircle(const Offset(0, -20), 3, Paint()..color = light);
      }
      for (final side in [-1.0, 1.0]) {
        final x = side * 40;
        canvas.drawPath(
          Path()
            ..moveTo(x, 2)
            ..lineTo(x - side * 12, 2)
            ..lineTo(x, 15)
            ..close(),
          Paint()..color = challengeGold,
        );
        canvas.drawPath(
          Path()
            ..moveTo(x, 38)
            ..lineTo(x - side * 12, 38)
            ..lineTo(x, 25)
            ..close(),
          Paint()..color = challengeGold,
        );
      }
      canvas.drawPath(
        Path()
          ..moveTo(0, 20)
          ..lineTo(8, 28)
          ..lineTo(0, 36)
          ..lineTo(-8, 28)
          ..close(),
        Paint()
          ..color = premium ? const Color(0xFF63E4EB) : const Color(0xFFB27AF2),
      );
      canvas.drawLine(
        const Offset(0, 22),
        const Offset(-4, 28),
        Paint()
          ..color = Colors.white.withValues(alpha: .8)
          ..strokeWidth = 1.5,
      );
      if (premium) {
        for (final side in [-1.0, 1.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(side * 10, 28)
              ..lineTo(side * 22, 18)
              ..lineTo(side * 18, 29)
              ..lineTo(side * 10, 34)
              ..close(),
            Paint()..color = challengeGold,
          );
        }
      }
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-9, -7, 18, 23),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFFFDA8E),
    );
    canvas.drawCircle(
      const Offset(0, 1),
      3,
      Paint()..color = const Color(0xFF50321B),
    );
    canvas.drawRect(
      const Rect.fromLTWH(-1.5, 1, 3, 6),
      Paint()..color = const Color(0xFF50321B),
    );
    canvas.restore();
  }

  void _star(Canvas canvas, Offset p, double r, Paint paint) {
    canvas.drawPath(
      Path()
        ..moveTo(p.dx, p.dy - r)
        ..lineTo(p.dx + r * .3, p.dy - r * .3)
        ..lineTo(p.dx + r, p.dy)
        ..lineTo(p.dx + r * .3, p.dy + r * .3)
        ..lineTo(p.dx, p.dy + r)
        ..lineTo(p.dx - r * .3, p.dy + r * .3)
        ..lineTo(p.dx - r, p.dy)
        ..lineTo(p.dx - r * .3, p.dy - r * .3)
        ..close(),
      paint,
    );
  }

  @override
  bool shouldRepaint(_RewardChest old) =>
      old.shine != shine ||
      old.opening != opening ||
      old.received != received ||
      old.reduced != reduced ||
      old.tier != tier;
}
