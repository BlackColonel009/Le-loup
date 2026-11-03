import 'dart:async';
import 'package:flutter/material.dart';
import '../cards/card_gallery.dart';
import '../social/social_api.dart';
import '../community/community_screen.dart';
import 'challenge_card.dart';
import 'challenge_sounds.dart';
import 'reward_claim_dialog.dart';
import '../social/social_service.dart';
import '../profile/avatar_gallery.dart';
import '../services/public_content.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({
    super.key,
    this.matchId,
    this.trainingReason,
    this.initialData,
    this.autoPresentRewards = true,
  });
  final String? matchId, trainingReason;
  final Map<String, dynamic>? initialData;
  final bool autoPresentRewards;
  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _busy = true, _all = false, _sounded = false;
  bool _requiresLogin = false;
  bool _rewardsOffered = false, _claimDialogOpen = false;
  String _filter = 'Tous';
  bool get _recap => widget.matchId != null && !_all;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
      _requiresLogin = false;
    });
    try {
      Map<String, dynamic>? data = widget.initialData;
      if (data == null || _all) {
        for (var attempt = 0; attempt < 4; attempt++) {
          try {
            data = await SocialApi.instance.request(
              _recap
                  ? '/challenges/matches/${widget.matchId}'
                  : '/challenges/me',
            );
            break;
          } on SocialError catch (error) {
            if (!_recap && error.status == 401) {
              try {
                data = await loadPublicContent('challenges/catalog');
                break;
              } catch (_) {
                throw error;
              }
            }
            if (!_recap || error.status != 404 || attempt == 3) rethrow;
            await Future<void>.delayed(
              Duration(milliseconds: 350 * (attempt + 1)),
            );
            if (!mounted) return;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _data = data;
        _busy = false;
      });
      if (widget.autoPresentRewards &&
          !_rewardsOffered &&
          _pending.isNotEmpty) {
        _rewardsOffered = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _claimRewards();
        });
      }
      if (_recap &&
          !_sounded &&
          _pending.isEmpty &&
          (data?['changes'] as List? ?? []).isNotEmpty) {
        _sounded = true;
        ChallengeSounds.play();
        final completed = (data!['changes'] as List).any(
          (c) => c['newly_completed'] == true,
        );
        if (completed) {
          Future<void>.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) ChallengeSounds.play(completed: true);
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _requiresLogin = error is SocialError && error.status == 401;
          _error = _requiresLogin
              ? 'Connectez votre compte de la communauté pour enregistrer vos défis et recevoir vos récompenses.'
              : error is SocialError
              ? error.message
              : 'Impossible de charger les défis. Vos progrès enregistrés sont conservés.';
        });
      }
    }
  }

  List<Map> get _pending =>
      (_data?['pending_challenges'] as List? ?? []).cast<Map>();

  Future<void> _claimRewards([List<Map>? selected]) async {
    if (_claimDialogOpen) return;
    final pending = selected ?? _pending;
    if (pending.isEmpty) return;
    _claimDialogOpen = true;
    try {
      await showRewardClaimDialog(
        context,
        challenges: pending,
        claim: (ids) => SocialApi.instance.request(
          '/challenges/claim',
          method: 'POST',
          body: {'challenge_ids': ids},
        ),
        onClaimed: (result) {
          SocialService.instance.updateChallengeRewards(
            result['pending_count'] as int? ?? 0,
            forUser: result['user_id'] as int?,
          );
          if (!mounted) return;
          final current = {
            for (final ch in (result['challenges'] as List).cast<Map>())
              ch['id']: ch,
          };
          setState(
            () => _data = {
              ...?_data,
              for (final key in ['challenges', 'changes'])
                if (_data?[key] is List)
                  key: [
                    for (final ch in (_data![key] as List).cast<Map>())
                      {...ch, ...?current[ch['id']]},
                  ],
              'pending_challenges': current.values
                  .where(
                    (ch) =>
                        ch['completed_at'] != null && ch['claimed_at'] == null,
                  )
                  .toList(),
              'pending_count': result['pending_count'],
            },
          );
        },
      );
    } finally {
      _claimDialogOpen = false;
    }
  }

  Future<void> _choose(Map challenge) async {
    final reward = (challenge['rewards'] as List).cast<Map>().firstWhere(
      (r) => r['kind'] == 'avatar_choice',
    );
    final choice = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Votre nouveau portrait'),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choisissez un portrait. Ce cadeau vous appartient définitivement.',
              ),
              const SizedBox(height: 18),
              for (final avatar in reward['choices'] as List)
                ListTile(
                  leading: ChallengeReward(reward: avatar as Map),
                  title: Text(avatar['title'] as String),
                  onTap: () => Navigator.pop(dialog, avatar['id'] as String),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Plus tard'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    try {
      await SocialApi.instance.request(
        '/challenges/choices/${challenge['id']}',
        method: 'POST',
        body: {'avatar_id': choice},
      );
      if (mounted) {
        setState(() => challenge['choice'] = choice);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Portrait ajouté à votre collection.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  void dispose() {
    ChallengeSounds.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = (_data?[_recap ? 'changes' : 'challenges'] as List? ?? [])
        .cast<Map>();
    final completed = list.where((c) => c['completed_at'] != null).length;
    final earned = _recap
        ? list.where((c) => c['newly_completed'] == true).length
        : completed;
    final visible = list
        .where(
          (c) =>
              _filter == 'Tous' ||
              (_filter == 'Accomplis'
                  ? c['completed_at'] != null
                  : c['completed_at'] == null),
        )
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(_recap ? 'Bilan de vos défis' : 'Le carnet des défis'),
      ),
      body: TavernBackground(
        dim: .94,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    margin: const EdgeInsets.only(bottom: 22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: challengeGold.withValues(alpha: .3),
                      ),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF26313A), Color(0xFF101A23)],
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: challengeGold,
                          size: 38,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _recap
                              ? 'Votre légende grandit'
                              : 'Chaque nuit laisse une trace',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(color: challengeGold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _recap
                              ? 'Vos actions de cette partie, vos prochains trésors.'
                              : '42 défis · des récompenses permanentes\nAvatars, bordures et stickers à gagner.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            height: 1.5,
                            color: Colors.white70,
                          ),
                        ),
                        if (!_busy && list.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                Chip(
                                  avatar: const Icon(Icons.explore, size: 17),
                                  label: Text(
                                    _recap
                                        ? '${list.length} progrès'
                                        : '${list.length} défis',
                                  ),
                                ),
                                Chip(
                                  avatar: const Icon(
                                    Icons.workspace_premium,
                                    size: 17,
                                    color: challengeGold,
                                  ),
                                  label: Text(
                                    '$earned défi${earned == 1 ? '' : 's'} accompli${earned == 1 ? '' : 's'}',
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_error != null) ...[
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _requiresLogin
                          ? () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const CommunityScreen(),
                                ),
                              );
                              if (mounted) _load();
                            }
                          : _load,
                      icon: Icon(_requiresLogin ? Icons.login : Icons.refresh),
                      label: Text(
                        _requiresLogin
                            ? 'Me connecter à la communauté'
                            : 'Réessayer',
                      ),
                    ),
                  ],
                  if (!_busy && _error == null) ...[
                    if (_data?['preview'] == true)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const Text(
                                'Connectez votre compte pour conserver vos progrès et réclamer vos cadeaux.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              FilledButton.icon(
                                onPressed: () async {
                                  await Navigator.of(context).push<void>(
                                    MaterialPageRoute(
                                      builder: (_) => const CommunityScreen(),
                                    ),
                                  );
                                  if (mounted) _load();
                                },
                                icon: const Icon(Icons.login),
                                label: const Text(
                                  'Me connecter à la communauté',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_pending.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 18),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: challengeGold.withValues(alpha: .13),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: challengeGold.withValues(alpha: .6),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'VOS CADEAUX VOUS ATTENDENT',
                              style: TextStyle(
                                color: challengeGold,
                                fontSize: 12,
                                letterSpacing: 1,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Bravo ! Des défis sont terminés. Récupérez vos récompenses pour les ajouter à votre collection.',
                            ),
                            const SizedBox(height: 14),
                            FilledButton.icon(
                              onPressed: () => _claimRewards(),
                              icon: const Icon(Icons.redeem),
                              label: const Text('Réclamer mes récompenses'),
                            ),
                          ],
                        ),
                      ),
                    if (widget.trainingReason != null ||
                        _data?['eligible'] == false)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            widget.trainingReason ?? _data!['reason'] as String,
                          ),
                        ),
                      ),
                    if (_recap && list.isEmpty && _data?['eligible'] != false)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Aucun nouveau palier cette fois. Vos récompenses et vos progrès précédents restent acquis.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (!_recap) ...[
                      Text(
                        _data?['rules'] as String? ?? '',
                        style: const TextStyle(
                          color: Colors.white60,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final filter in [
                            'Tous',
                            'En cours',
                            'Accomplis',
                          ])
                            ChoiceChip(
                              label: Text(filter),
                              selected: _filter == filter,
                              onSelected: (_) =>
                                  setState(() => _filter = filter),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    for (var i = 0; i < visible.length; i++)
                      ChallengeCard(
                        key: ValueKey('$_recap-${visible[i]['id']}'),
                        challenge: visible[i],
                        animate: _recap,
                        delay: Duration(milliseconds: (i * 120).clamp(0, 700)),
                        onChoose: () => _choose(visible[i]),
                        onClaim: () => _claimRewards([visible[i]]),
                      ),
                  ],
                  if (_recap)
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _all = true;
                          _data = null;
                        });
                        _load();
                      },
                      icon: const Icon(Icons.menu_book),
                      label: const Text('Consulter tous mes défis'),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AvatarGalleryScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.face_retouching_natural),
                    label: const Text('Mes portraits et bordures'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.cottage_outlined),
                    label: Text(
                      widget.matchId == null
                          ? 'Continuer mon aventure'
                          : 'Retourner au village',
                    ),
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
