import 'package:flutter/material.dart';
import '../social/social_api.dart';
import '../social/social_service.dart';
import '../services/public_content.dart';
import 'challenges_screen.dart';
import 'challenge_card.dart';

/// Stable order: gifts to collect, started challenges, then untouched ones.
List<Map> orderedChallengePreview(List<Map> challenges) {
  int rank(Map c) {
    if (c['completed_at'] != null) return c['claimed_at'] == null ? 0 : 3;
    return (c['progress'] as num? ?? 0) > 0 ? 1 : 2;
  }

  final indexed = challenges.indexed.toList()
    ..sort((a, b) {
      final order = rank(a.$2).compareTo(rank(b.$2));
      return order == 0 ? a.$1.compareTo(b.$1) : order;
    });
  final unfinished = indexed
      .where((entry) => rank(entry.$2) < 3)
      .map((entry) => entry.$2)
      .toList();
  return (unfinished.isEmpty ? indexed.map((entry) => entry.$2) : unfinished)
      .take(3)
      .toList();
}

Future<Map<String, dynamic>> loadChallengeDiscovery() async {
  try {
    return await SocialApi.instance.request('/challenges/me');
  } on SocialError catch (error) {
    if (error.status != 401) rethrow;
    return loadPublicContent('challenges/catalog');
  }
}

Future<void> showChallengeDiscovery(
  BuildContext context, {
  Future<Map<String, dynamic>> Function()? load,
}) async {
  try {
    final data = await (load?.call() ?? loadChallengeDiscovery()).timeout(
      const Duration(seconds: 3),
    );
    if (!context.mounted || ModalRoute.of(context)?.isCurrent != true) return;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    if ((data['challenges'] as List? ?? []).isEmpty) return;
    final open = await showDialog<bool>(
      context: context,
      builder: (_) => ChallengeDiscoveryDialog(data: data),
    );
    if (open == true && context.mounted) {
      await Navigator.of(
        context,
      ).push<void>(MaterialPageRoute(builder: (_) => const ChallengesScreen()));
    }
  } catch (_) {
    // A small optional welcome must never delay local play or show stale data.
  }
}

class ChallengeDiscoveryDialog extends StatelessWidget {
  const ChallengeDiscoveryDialog({super.key, required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final challenges = (data['challenges'] as List? ?? []).cast<Map>();
    final items = orderedChallengePreview(challenges);
    final pending = (data['pending_count'] as num? ?? 0) > 0;
    final started = items.any(
      (c) => c['completed_at'] == null && (c['progress'] as num? ?? 0) > 0,
    );
    return Dialog(
      backgroundColor: const Color(0xFF111D27),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: BorderSide(color: challengeGold.withValues(alpha: .65)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 470,
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: challengeGold,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Vos défis du moment',
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: challengeGold),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer l’aperçu des défis',
                    onPressed: () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      pending
                          ? 'Bravo ! Des cadeaux vous attendent.'
                          : started
                          ? 'Votre aventure continue. Voici vos progrès.'
                          : 'Tout commence par une première partie !',
                      style: const TextStyle(
                        color: Color(0xFFE7DDC7),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Portraits, bordures et stickers à gagner.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    for (final item in items)
                      _DiscoveryProgress(challenge: item),
                    if (data['preview'] == true)
                      const Padding(
                        padding: EdgeInsets.only(top: 4, bottom: 8),
                        child: Text(
                          'Connectez votre compte pour conserver vos progrès.',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: Icon(pending ? Icons.redeem : Icons.explore_outlined),
                    label: Text(
                      pending
                          ? 'Réclamer mes récompenses'
                          : 'Voir tous mes défis',
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Fermer et continuer'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryProgress extends StatelessWidget {
  const _DiscoveryProgress({required this.challenge});
  final Map challenge;
  @override
  Widget build(BuildContext context) {
    final target = ((challenge['target'] as num?)?.toInt() ?? 1).clamp(
      1,
      999999,
    );
    final value = ((challenge['progress'] as num?)?.toInt() ?? 0).clamp(
      0,
      target,
    );
    final complete = challenge['completed_at'] != null;
    final color = complete ? challengeGold : const Color(0xFF81D4C3);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2933),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  challenge['title'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$value / $target',
                style: TextStyle(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            challenge['description'] as String,
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value / target),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, progress, _) => ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                key: ValueKey('discovery-${challenge['id']}'),
                value: progress,
                minHeight: 8,
                backgroundColor: const Color(0xFF081219),
                color: color,
                semanticsLabel: challenge['title'] as String,
                semanticsValue: '${(progress * 100).round()}%',
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            complete
                ? challenge['claimed_at'] == null
                      ? 'Cadeau à réclamer'
                      : 'Accompli'
                : value > 0
                ? 'En cours'
                : 'À commencer',
            style: TextStyle(color: color, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class ChallengesHomeShortcut extends StatefulWidget {
  const ChallengesHomeShortcut({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  State<ChallengesHomeShortcut> createState() => _ChallengesHomeShortcutState();
}

class _ChallengesHomeShortcutState extends State<ChallengesHomeShortcut>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  bool _reduced = false, _background = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _sync() {
    if (_reduced || _background) {
      _glow.stop();
    } else if (!_glow.isAnimating) {
      _glow.repeat(reverse: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _background = state != AppLifecycleState.resumed;
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: SocialService.instance,
    builder: (_, _) => AnimatedBuilder(
      animation: _glow,
      builder: (_, _) {
        final gifts = SocialService.instance.challengeRewards;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: challengeGold.withValues(alpha: .12 + _glow.value * .13),
                blurRadius: 12 + _glow.value * 10,
              ),
            ],
          ),
          child: Material(
            color: const Color(0xFF282A26),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              key: const ValueKey('home-challenges'),
              borderRadius: BorderRadius.circular(20),
              onTap: widget.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: challengeGold.withValues(
                      alpha: .5 + _glow.value * .4,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Badge(
                      isLabelVisible: gifts > 0,
                      label: Text('$gifts'),
                      child: const Icon(
                        Icons.emoji_events_rounded,
                        color: challengeGold,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Défis & récompenses',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: const Color(0xFFFFE8B2),
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            gifts > 0
                                ? 'Des cadeaux vous attendent !'
                                : 'Jouez · progressez · gagnez des cadeaux',
                            style: const TextStyle(
                              color: Color(0xFFD6C6A6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, color: challengeGold),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
