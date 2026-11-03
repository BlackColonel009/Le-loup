import 'dart:async';
import 'package:flutter/material.dart';
import '../content/content_image.dart';
import '../profile/player_avatar.dart';
import '../profile/avatar_border.dart';

const challengeGold = Color(0xFFE5C385);

class ChallengeReward extends StatelessWidget {
  const ChallengeReward({super.key, required this.reward, this.size = 44});
  final Map reward;
  final double size;
  @override
  Widget build(BuildContext context) {
    final kind = reward['kind'];
    if (kind == 'avatar') {
      return PlayerAvatar(
        size: size,
        avatar: {'id': reward['id'], 'kind': 'game'},
        nickname: reward['title'] as String? ?? 'Portrait',
      );
    }
    if (kind == 'border') {
      final border = avatarBorder(reward['id'] as String?);
      if (border != null) {
        return SizedBox.square(
          dimension: size,
          child: AnimatedAvatarBorder(
            border: border,
            animate: false,
            child: const Icon(Icons.person, color: Colors.white54),
          ),
        );
      }
    }
    if (kind == 'sticker' && reward['asset'] is String) {
      return SizedBox.square(
        dimension: size,
        child: ContentImage(
          reward['asset'] as String,
          fit: BoxFit.contain,
          autoDownload: false,
        ),
      );
    }
    return Icon(Icons.auto_awesome, size: size * .65, color: challengeGold);
  }
}

class ChallengeCard extends StatefulWidget {
  const ChallengeCard({
    super.key,
    required this.challenge,
    this.animate = false,
    this.delay = Duration.zero,
    this.onChoose,
    this.onClaim,
  });
  final Map challenge;
  final bool animate;
  final Duration delay;
  final VoidCallback? onChoose;
  final VoidCallback? onClaim;
  @override
  State<ChallengeCard> createState() => _ChallengeCardState();
}

class _ChallengeCardState extends State<ChallengeCard>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );
  Timer? _delay;
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      _motion.value = 1;
    } else {
      _delay = Timer(widget.delay, () {
        if (mounted) _motion.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    final goal = (c['target'] as num).toInt();
    final current = (c['progress'] as num? ?? 0).toInt().clamp(0, goal);
    final before = widget.animate
        ? (c['before'] as num? ?? 0).toDouble().clamp(0, current.toDouble())
        : current.toDouble();
    final completed = c['completed_at'] != null;
    final claimable =
        completed && c.containsKey('claimed_at') && c['claimed_at'] == null;
    final color = completed ? challengeGold : const Color(0xFF80D6CC);
    final rewards = (c['rewards'] as List? ?? []).cast<Map>();
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF142029).withValues(alpha: .94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: color.withValues(alpha: completed ? .65 : .22),
        ),
        boxShadow: [
          if (completed)
            BoxShadow(color: color.withValues(alpha: .09), blurRadius: 22),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: .12),
                ),
                child: Icon(
                  claimable
                      ? Icons.redeem
                      : completed
                      ? Icons.workspace_premium
                      : Icons.explore_outlined,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c['category'] as String? ?? 'Défi',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c['title'] as String,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (completed)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(
                    claimable ? Icons.card_giftcard : Icons.check_circle,
                    color: challengeGold,
                    size: 20,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            c['description'] as String,
            style: const TextStyle(color: Color(0xFFCDD6D9), height: 1.45),
          ),
          const SizedBox(height: 17),
          AnimatedBuilder(
            animation: _motion,
            builder: (_, _) {
              final t = Curves.easeInOutCubic.transform(_motion.value);
              final value = before + (current - before) * t;
              return Semantics(
                label: '${c['title']}, $current sur $goal',
                value: '$current/$goal',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            completed
                                ? (claimable
                                      ? 'CADEAU À RÉCLAMER'
                                      : c['newly_completed'] == true
                                      ? 'NOUVELLE RÉCOMPENSE'
                                      : 'DÉFI ACCOMPLI')
                                : 'Votre progression',
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${value.floor()} / $goal',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: SizedBox(
                        key: ValueKey('challenge-bar-${c['id']}'),
                        width: double.infinity,
                        height: 11,
                        child: LayoutBuilder(
                          builder: (_, bounds) => Stack(
                            children: [
                              const Positioned.fill(
                                child: ColoredBox(color: Color(0xFF081218)),
                              ),
                              SizedBox(
                                key: ValueKey('challenge-fill-${c['id']}'),
                                width: bounds.maxWidth * (value / goal),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        color.withValues(alpha: .4),
                                        color,
                                        const Color(0xFFFFE9B8),
                                      ],
                                    ),
                                  ),
                                  child: const SizedBox(height: 11),
                                ),
                              ),
                              if (_motion.isAnimating && value > 0)
                                Positioned(
                                  left: (bounds.maxWidth * value / goal - 4)
                                      .clamp(0, bounds.maxWidth - 8),
                                  child: Container(
                                    width: 8,
                                    height: 11,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      boxShadow: [
                                        BoxShadow(
                                          color: color,
                                          blurRadius: 12,
                                          spreadRadius: 4,
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
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          for (final reward in rewards)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  ChallengeReward(reward: reward),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      reward['title'] as String? ?? 'Récompense',
                      style: const TextStyle(
                        color: Color(0xFFE2D6BA),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(
                    completed
                        ? claimable
                              ? Icons.card_giftcard
                              : Icons.lock_open_rounded
                        : Icons.lock_outline_rounded,
                    size: 16,
                    color: completed ? challengeGold : Colors.white38,
                  ),
                ],
              ),
            ),
          if (claimable)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.onClaim,
                  icon: const Icon(Icons.redeem),
                  label: const Text('Réclamer ma récompense'),
                ),
              ),
            ),
          if (completed &&
              !claimable &&
              rewards.any((r) => r['kind'] == 'avatar_choice'))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: FilledButton.tonalIcon(
                onPressed: c['choice'] == null ? widget.onChoose : null,
                icon: Icon(c['choice'] == null ? Icons.face : Icons.check),
                label: Text(
                  c['choice'] == null
                      ? 'Choisir mon portrait'
                      : 'Portrait reçu',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
