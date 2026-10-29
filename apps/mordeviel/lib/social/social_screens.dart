import 'dart:async';
import 'package:flutter/material.dart';
import '../community/community_screen.dart';
import 'social_api.dart';
import 'private_chat_screen.dart';
import 'presence_badge.dart';
import 'social_service.dart';
import 'social_notifications.dart';
import 'online_navigation.dart';
import '../services/game_notification_sound.dart';

const _gold = Color(0xFFE1BA78);
String _date(dynamic value) {
  final d = DateTime.fromMillisecondsSinceEpoch(
    ((value as num) * 1000).round(),
  ).toLocal();
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

bool _yes(dynamic value) => value == true || value == 1;

class SocialActionBar extends StatefulWidget {
  const SocialActionBar({super.key});
  @override
  State<SocialActionBar> createState() => _SocialActionBarState();
}

class _SocialActionBarState extends State<SocialActionBar> {
  @override
  void initState() {
    super.initState();
    SocialService.instance.start();
    SocialService.instance.addListener(_presenceNotice);
    pendingSocialNotification.addListener(_notificationTap);
    initializeSocialNotificationUi();
  }

  @override
  void dispose() {
    pendingSocialNotification.removeListener(_notificationTap);
    SocialService.instance.release();
    SocialService.instance.removeListener(_presenceNotice);
    super.dispose();
  }

  void _presenceNotice() {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final message = SocialService.instance.takePresenceAnnouncement();
    if (message == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.circle, size: 12, color: Color(0xFF7BC995)),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _open(int tab) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SocialHubScreen(initialTab: tab)),
    );
    await SocialService.instance.refresh();
  }

  void _notificationTap() {
    final kind = pendingSocialNotification.value;
    if (kind == null) return;
    pendingSocialNotification.value = null;
    // Android brings the existing game activity back; do not open social tabs.
    if (kind.startsWith('game-start:')) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _open(kind == 'invitation' ? 2 : 0);
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: SocialService.instance,
    builder: (context, _) {
      final social = SocialService.instance;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Amis et profil',
            onPressed: () => _open(0),
            icon: Badge(
              isLabelVisible: social.friendRequests > 0,
              label: Text('${social.friendRequests}'),
              child: const Icon(Icons.people_outline),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: social.invitations > 0
                  ? [
                      BoxShadow(
                        color: _gold.withValues(alpha: .3),
                        blurRadius: 15,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: IconButton(
              tooltip: 'Invitations',
              onPressed: () => _open(2),
              icon: Badge(
                isLabelVisible: social.invitations > 0,
                label: Text('${social.invitations}'),
                child: Icon(
                  Icons.mark_email_unread_outlined,
                  color: social.invitations > 0 ? _gold : null,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class SocialHubScreen extends StatefulWidget {
  const SocialHubScreen({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  State<SocialHubScreen> createState() => _SocialHubScreenState();
}

class _SocialHubScreenState extends State<SocialHubScreen> {
  Timer? _timer;
  List _friends = [], _recent = [], _invitations = [];
  bool _busy = true, _signed = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_busy &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _busy = true;
        _error = null;
      });
    }
    try {
      final data = await Future.wait([
        SocialApi.instance.request('/social/friends'),
        SocialApi.instance.request('/social/recent'),
        SocialApi.instance.request('/social/invitations'),
      ]);
      if (mounted) {
        setState(() {
          _signed = true;
          _friends = data[0]['friends'] as List;
          _recent = data[1]['players'] as List;
          _invitations = data[2]['invitations'] as List;
        });
      }
      await SocialService.instance.refresh();
    } on SocialError catch (e) {
      if (mounted) {
        setState(() {
          _signed = e.status != 401 && e.status != 403;
          _error = e.message;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _friend(int id, String action) async {
    try {
      await SocialApi.instance.request(
        '/social/friends/$id',
        method: 'POST',
        body: {'action': action},
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _visit(int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => SocialProfileScreen(userId: id)),
    );
    await _load();
  }

  Widget _empty(IconData icon, String title, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
    child: Column(
      children: [
        Icon(icon, size: 60, color: _gold),
        const SizedBox(height: 18),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(text, textAlign: TextAlign.center),
      ],
    ),
  );
  Widget _person(Map p, {required bool recent}) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: _gold.withValues(alpha: .13),
              child: Icon(
                p['online'] == true ? Icons.person : Icons.person_outline,
                color: _gold,
              ),
            ),
            title: Text(p['nickname'] as String),
            subtitle: Text(
              recent
                  ? '${p['games']} partie(s) ensemble · ${_date(p['played_at'])}'
                  : p['status'] == 'pending'
                  ? p['incoming'] == true
                        ? 'Souhaite rejoindre ton cercle'
                        : 'Demande envoyée'
                  : 'Ami du village',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _visit(p['id'] as int),
          ),
          if (!recent && p['status'] == 'accepted')
            FriendPresenceBadge(person: p),
          if (recent && p['is_friend'] != true)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => _friend(p['id'] as int, 'request'),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Ajouter en ami'),
              ),
            ),
          if (!recent && p['status'] == 'pending')
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              children: [
                if (p['incoming'] == true)
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _friend(p['id'] as int, 'accept'),
                    child: const Text('Accepter'),
                  ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _friend(
                          p['id'] as int,
                          p['incoming'] == true ? 'decline' : 'cancel',
                        ),
                  child: Text(p['incoming'] == true ? 'Refuser' : 'Annuler'),
                ),
              ],
            ),
          if (p['is_friend'] == true || (!recent && p['status'] == 'accepted'))
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PrivateChatScreen(
                    friendId: p['id'] as int,
                    nickname: p['nickname'] as String,
                  ),
                ),
              ),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Message privé · 24 h'),
            ),
        ],
      ),
    ),
  );
  Future<void> _invite(Map invite) async {
    try {
      await SocialApi.instance.request(
        '/social/invitations/${invite['id']}/seen',
        method: 'POST',
      );
      if (!mounted) return;
      if (invite['room'] is Map &&
          (invite['room'] as Map)['joinable'] == true) {
        await openOnlineLobby(context, code: invite['room']['code'] as String);
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Widget _invitation(Map i) {
    final active = i['status'] == 'active', room = i['room'] as Map?;
    final status = switch (i['status']) {
      'closed' => 'Salon fermé',
      'started' => 'Partie commencée',
      'expired' => 'Invitation expirée',
      'cancelled' => 'Invitation annulée',
      'accepted' => 'Salon rejoint',
      'declined' => 'Invitation refusée',
      _ =>
        room?['joinable'] == true
            ? 'Ta place t’attend'
            : 'Salon momentanément complet ou verrouillé',
    };
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: active ? _gold : Colors.white12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: active
              ? LinearGradient(
                  colors: [
                    _gold.withValues(alpha: .10),
                    const Color(0xFF172230),
                  ],
                )
              : null,
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          spacing: 8,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  active ? Icons.mail_outline : Icons.drafts_outlined,
                  color: active ? _gold : Colors.grey,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${i['nickname']} t’invite',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (active && i['seen'] == 0)
                  const Badge(label: Text('Nouveau')),
              ],
            ),
            const SizedBox(height: 10),
            Text(room?['title'] as String? ?? 'Une soirée au village'),
            if (room != null)
              Text(
                '${themeName(room['theme'])} · ${room['players']}/${room['capacity']} joueurs',
              ),
            const SizedBox(height: 8),
            Text(
              '$status · ${_date(i['created'])}',
              style: TextStyle(color: active ? _gold : Colors.grey),
            ),
            if (active)
              TextButton(
                onPressed: () async {
                  try {
                    await SocialApi.instance.request(
                      '/social/invitations/${i['id']}/decline',
                      method: 'POST',
                    );
                    await _load();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
                child: const Text('Décliner l’invitation'),
              ),
            if (active)
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => _invite(i),
                  icon: Icon(
                    room?['joinable'] == true ? Icons.login : Icons.done,
                  ),
                  label: Text(
                    room?['joinable'] == true
                        ? 'Rejoindre le salon'
                        : 'Marquer comme vue',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    initialIndex: widget.initialTab,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Ton cercle du village'),
        actions: [
          IconButton(
            tooltip: 'Mon profil',
            onPressed: () => Navigator.of(context)
                .push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SocialProfileScreen(),
                  ),
                )
                .then((_) => _load()),
            icon: Badge(
              isLabelVisible: SocialService.instance.friendRequests > 0,
              child: const Icon(Icons.account_circle_outlined),
            ),
          ),
          IconButton(
            onPressed: _load,
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: _signed
            ? const TabBar(
                tabs: [
                  Tab(icon: Icon(Icons.people_outline), text: 'Amis'),
                  Tab(icon: Icon(Icons.history), text: 'Récents'),
                  Tab(icon: Icon(Icons.mail_outline), text: 'Invitations'),
                ],
              )
            : null,
      ),
      body: !_signed && !_busy
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.night_shelter_outlined,
                      size: 72,
                      color: _gold,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Retrouve tes compagnons de jeu',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error ??
                          'Connecte ton compte communauté pour retrouver tes amis et tes invitations.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CommunityScreen(),
                          ),
                        );
                        await _load();
                      },
                      child: const Text('Me connecter à la communauté'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                if (_busy) const LinearProgressIndicator(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_error!),
                  ),
                Expanded(
                  child: TabBarView(
                    children: [
                      RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (_friends.isEmpty)
                              _empty(
                                Icons.people_outline,
                                'Un cercle à construire',
                                'Retrouve les joueurs croisés pendant tes parties et invite-les à devenir tes amis.',
                              ),
                            for (final p in _friends)
                              _person(p as Map, recent: false),
                          ],
                        ),
                      ),
                      RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (_recent.isEmpty)
                              _empty(
                                Icons.history,
                                'Les rencontres restent ici',
                                'Les participants connectés à leur compte apparaîtront après une partie en ligne commencée.',
                              ),
                            for (final p in _recent)
                              _person(p as Map, recent: true),
                          ],
                        ),
                      ),
                      RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (_invitations.isEmpty)
                              _empty(
                                Icons.mail_outline,
                                'Le calme avant la nuit',
                                'Les invitations de tes amis apparaîtront ici. Les anciennes resteront dans ton historique.',
                              ),
                            for (final i in _invitations) _invitation(i as Map),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    ),
  );
}

class StatsGrid extends StatelessWidget {
  const StatsGrid({super.key, required this.stats});
  final Map stats;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final metric in [
          ('wins', 'Victoires', Icons.emoji_events_outlined),
          ('wolf_victims', 'Victimes en loup', Icons.nightlight_round),
          ('devoured', 'Dévorations subies', Icons.pets_outlined),
          ('executed', 'Exécutions subies', Icons.gavel),
          ('games', 'Parties terminées', Icons.casino_outlined),
        ])
          SizedBox(
            width: (box.maxWidth - 10) / 2,
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(metric.$3, color: _gold, size: 22),
                    const SizedBox(height: 8),
                    Text(
                      '${stats[metric.$1] ?? 0}',
                      style: Theme.of(
                        context,
                      ).textTheme.headlineMedium?.copyWith(color: _gold),
                    ),
                    Text(
                      metric.$2,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class SocialProfileScreen extends StatefulWidget {
  const SocialProfileScreen({super.key, this.userId});
  final int? userId;
  @override
  State<SocialProfileScreen> createState() => _SocialProfileScreenState();
}

class _SocialProfileScreenState extends State<SocialProfileScreen> {
  Timer? _statsPoll;
  Map<String, dynamic>? _data;
  bool _busy = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
    _statsPoll = Timer.periodic(const Duration(seconds: 10), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _statsPoll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await SocialApi.instance.request(
        widget.userId == null
            ? '/social/me'
            : '/social/profiles/${widget.userId}',
      );
      if (data['is_self'] == true) {
        final sound = (data['preferences'] as Map?)?['game_notification_sound'];
        if (sound is String) await saveGameNotificationSound(sound);
      }
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(String key, dynamic value) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (key == 'phone_notifications' &&
          value == true &&
          !await enablePhoneNotifications()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Autorise les notifications sur ton téléphone Android pour activer cette option.',
              ),
            ),
          );
        }
        return;
      }
      final pref = Map<String, dynamic>.from(_data!['preferences'] as Map);
      final body = {
        'stats_visibility': pref['stats_visibility'],
        'invite_emails': _yes(pref['invite_emails']),
        'phone_notifications': _yes(pref['phone_notifications']),
        'auto_invite': _yes(pref['auto_invite']),
        'game_notification_sound': pref['game_notification_sound'] ?? 'game',
        key: value,
      };
      await SocialApi.instance.request(
        '/social/preferences',
        method: 'PUT',
        body: body,
      );
      if (key == 'game_notification_sound') {
        await saveGameNotificationSound(value as String);
      }
      if (key == 'phone_notifications' && value == false) {
        await disablePhoneNotifications();
      }
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _act(String action) async {
    setState(() => _busy = true);
    try {
      await SocialApi.instance.request(
        '/social/friends/${_data!['id']}',
        method: 'POST',
        body: {'action': action},
      );
      await _load();
      await SocialService.instance.refresh();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _block() async {
    final blocked = _data!['blocked_by_me'] == true;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(blocked ? 'Débloquer ce joueur ?' : 'Bloquer ce joueur ?'),
        content: const Text(
          'Le blocage empêche les nouvelles demandes et invitations entre vous.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await SocialApi.instance.request(
        '/social/blocks/${_data!['id']}',
        method: 'PUT',
        body: {'blocked': !blocked},
      );
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _data, pref = p?['preferences'] as Map?;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          p?['is_self'] == true ? 'Mon carnet de joueur' : 'Profil du joueur',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (p != null) ...[
            const SizedBox(height: 12),
            const CircleAvatar(
              radius: 42,
              backgroundColor: Color(0xFF28313B),
              child: Icon(Icons.person_outline, size: 54, color: _gold),
            ),
            const SizedBox(height: 16),
            Text(
              p['nickname'] as String,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            if (p['presence'] != null && p['is_friend'] == true)
              FriendPresenceBadge(person: p),
            if (p['verified'] == true)
              const Center(
                child: Chip(
                  avatar: Icon(Icons.verified, size: 18),
                  label: Text('Administrateur certifié'),
                ),
              ),
            const SizedBox(height: 24),
            if (p['stats_visible'] == true) ...[
              StatsGrid(stats: p['stats'] as Map),
              const Text(
                'Statistiques des parties en ligne entre joueurs humains.',
              ),
              if (p['practice_stats'] is Map &&
                  ((p['practice_stats'] as Map)['games'] as num? ?? 0) > 0) ...[
                const SizedBox(height: 16),
                const Text('Mes parties avec bots · Résultats personnels'),
                StatsGrid(stats: p['practice_stats'] as Map),
              ],
              const SizedBox(height: 12),
              const Text(
                'Résultats de parties en ligne terminées. Les victimes de la meute sont des éliminations collectives confirmées.',
                style: TextStyle(fontSize: 12, color: Colors.white60),
              ),
              if (p['is_self'] == true)
                const Text(
                  'Connecte ton compte et joue un rôle pour enregistrer tes résultats. Le MDJ n’appartient à aucun camp et ne reçoit pas de victoire personnelle.',
                ),
            ] else
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(Icons.lock_outline, size: 38, color: _gold),
                      SizedBox(height: 12),
                      Text(
                        'Ce carnet est réservé aux amis.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 22),
            if (p['is_self'] == true && pref != null) ...[
              Text(
                'Ton espace, tes règles',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('profile-stats-visibility'),
                initialValue: pref['stats_visibility'] as String,
                decoration: const InputDecoration(
                  labelText: 'Qui peut voir mes statistiques ?',
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'public',
                    child: Text('Tous les joueurs'),
                  ),
                  DropdownMenuItem(
                    value: 'friends',
                    child: Text('Mes amis uniquement'),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (v) {
                        if (v != null) _save('stats_visibility', v);
                      },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Inviter mes amis quand je crée un salon'),
                value: _yes(pref['auto_invite']),
                onChanged: _busy ? null : (v) => _save('auto_invite', v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Emails d’invitation'),
                subtitle: const Text(
                  'Pour les invitations reçues lorsque tu es absent.',
                ),
                value: _yes(pref['invite_emails']),
                onChanged: _busy ? null : (v) => _save('invite_emails', v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notifications sur mon téléphone'),
                subtitle: const Text(
                  'Sans Firebase. En arrière-plan, Android peut retarder la réception.',
                ),
                value: _yes(pref['phone_notifications']),
                onChanged: _busy
                    ? null
                    : (v) => _save('phone_notifications', v),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'game-sound-${pref['game_notification_sound'] ?? 'game'}-$_busy',
                ),
                initialValue:
                    pref['game_notification_sound'] as String? ?? 'game',
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Son de début de partie',
                  helperText:
                      'L’alerte qui t’invite à revenir quand le MDJ lance la partie.',
                  helperMaxLines: 2,
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'game',
                    child: Text(
                      'Mordeviel · Voix et suspense',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'phone',
                    child: Text(
                      'Son standard du téléphone',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                onChanged: _busy
                    ? null
                    : (value) {
                        if (value != null) {
                          _save('game_notification_sound', value);
                        }
                      },
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SocialHubScreen(),
                  ),
                ),
                icon: Badge(
                  isLabelVisible: SocialService.instance.friendRequests > 0,
                  label: Text('${SocialService.instance.friendRequests}'),
                  child: const Icon(Icons.people_outline),
                ),
                label: const Text('Mes amis et mes demandes'),
              ),
            ] else ...[
              if (p['blocked_by_me'] != true)
                if (p['is_friend'] == true)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _act('remove'),
                    icon: const Icon(Icons.person_remove_outlined),
                    label: const Text('Retirer de mes amis'),
                  )
                else if (p['relationship'] == 'pending')
                  Wrap(
                    spacing: 10,
                    children: [
                      if (p['request_incoming'] == true)
                        FilledButton(
                          onPressed: _busy ? null : () => _act('accept'),
                          child: const Text('Accepter la demande'),
                        ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _act(
                                p['request_incoming'] == true
                                    ? 'decline'
                                    : 'cancel',
                              ),
                        child: Text(
                          p['request_incoming'] == true
                              ? 'Refuser'
                              : 'Annuler ma demande',
                        ),
                      ),
                    ],
                  )
                else
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _act('request'),
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Ajouter à mes amis'),
                  ),
              TextButton.icon(
                onPressed: _busy ? null : _block,
                icon: const Icon(Icons.block),
                label: Text(
                  p['blocked_by_me'] == true
                      ? 'Débloquer'
                      : 'Bloquer ce joueur',
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class ProfileSocialCard extends StatefulWidget {
  const ProfileSocialCard({super.key});
  @override
  State<ProfileSocialCard> createState() => _ProfileSocialCardState();
}

class _ProfileSocialCardState extends State<ProfileSocialCard> {
  Timer? _statsPoll;
  Map? _data;
  @override
  void initState() {
    super.initState();
    _load();
    _statsPoll = Timer.periodic(const Duration(seconds: 10), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _statsPoll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await SocialApi.instance.request('/social/me');
      if (mounted) setState(() => _data = data);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (_data?['stats'] is Map) StatsGrid(stats: _data!['stats'] as Map),
      if (_data?['practice_stats'] is Map &&
          ((_data!['practice_stats'] as Map)['games'] as num? ?? 0) > 0) ...[
        const Text('Mes parties avec bots'),
        StatsGrid(stats: _data!['practice_stats'] as Map),
      ],
      ListTile(
        leading: const Icon(Icons.shield_moon_outlined, color: _gold),
        title: const Text('Statistiques, amis et confidentialité'),
        trailing: Badge(
          isLabelVisible: SocialService.instance.friendRequests > 0,
          label: Text('${SocialService.instance.friendRequests}'),
          child: const Icon(Icons.chevron_right),
        ),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const SocialProfileScreen(),
            ),
          );
          await _load();
        },
      ),
    ],
  );
}
