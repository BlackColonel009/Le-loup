import 'dart:async';
import 'package:flutter/material.dart';
import '../audio/audio_settings.dart';
import '../challenges/challenges_screen.dart';
import '../community/community_screen.dart';
import '../content/downloads_screen.dart';
import '../content/pack_store.dart';
import '../profile/player_avatar.dart';
import '../profile/avatar_border.dart';
import '../social/social_notifications.dart';
import '../social/social_screens.dart';
import '../social/social_service.dart';
import '../store/store_screen.dart';

const _gold = Color(0xFFE1BA78);

enum _Destination { store, friends, invitations, challenges }

/// The home identity uses the same equipped portrait and effects as the profile.
class HomeTopBar extends StatefulWidget implements PreferredSizeWidget {
  const HomeTopBar({super.key, this.onAccountChanged});
  final VoidCallback? onAccountChanged;
  @override
  Size get preferredSize => const Size.fromHeight(76);
  @override
  State<HomeTopBar> createState() => _HomeTopBarState();
}

class _HomeTopBarState extends State<HomeTopBar>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _social = SocialService.instance;
  final _packs = PackStore.instance;
  late final AnimationController _pulse;
  bool _menuOpen = false, _paused = false, _reduced = false;

  Set<String> get _packNews {
    final ids = <String>{};
    for (final pack in _packs.packs) {
      if (!_packs.installed(pack['id'] as String) &&
          (pack['files'] as List).any(
            (f) => _packs.pathFor(f['asset'] as String) != null,
          )) {
        ids.add(pack['id'] as String);
      }
    }
    final portraitPack = _social.avatar?['pack_id'] as String?;
    if (_social.avatar?['kind'] == 'game' &&
        portraitPack != null &&
        !_packs.installed(portraitPack)) {
      ids.add(portraitPack);
    }
    final borderPack =
        avatarBorder(_social.avatar?['border_id'] as String?)?['pack_id']
            as String?;
    if (borderPack != null && !_packs.installed(borderPack)) {
      ids.add(borderPack);
    }
    return ids;
  }

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
    );
    WidgetsBinding.instance.addObserver(this);
    _social.addListener(_changed);
    _packs.addListener(_changed);
    pendingSocialNotification.addListener(_notificationTap);
    _social.start();
    initializeSocialNotificationUi();
    unawaited(_refreshPacks());
    WidgetsBinding.instance.addPostFrameCallback((_) => _notificationTap());
  }

  Future<void> _refreshPacks() async {
    try {
      await _packs.initialize();
      await _packs.refresh();
    } catch (_) {
      // Optional downloads never hold the home screen open.
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced =
        MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled;
    _syncPulse();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _paused = state != AppLifecycleState.resumed;
    _syncPulse();
  }

  void _syncPulse() {
    if (!_paused && !_reduced && (_social.hasNews || _packNews.isNotEmpty)) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
    }
  }

  void _changed() {
    if (!mounted) return;
    _syncPulse();
    setState(() {});
    final message = _social.takePresenceAnnouncement();
    if (message != null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
      );
    }
  }

  void _notificationTap() {
    final kind = pendingSocialNotification.value;
    if (!mounted || kind == null) return;
    if (kind.startsWith('chat:')) return;
    pendingSocialNotification.value = null;
    if (kind.startsWith('game-start:')) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(
          _open(SocialHubScreen(initialTab: kind == 'invitation' ? 2 : 0)),
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pendingSocialNotification.removeListener(_notificationTap);
    _social.removeListener(_changed);
    _packs.removeListener(_changed);
    _social.release();
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    await _social.refresh(afterCurrent: true);
    if (mounted) widget.onAccountChanged?.call();
  }

  void _select(_Destination destination) {
    setState(() => _menuOpen = false);
    unawaited(
      _open(switch (destination) {
        _Destination.store => const StoreScreen(),
        _Destination.friends => const SocialHubScreen(initialTab: 0),
        _Destination.invitations => const SocialHubScreen(initialTab: 2),
        _Destination.challenges => const ChallengesScreen(),
      }),
    );
  }

  Widget _news({required int count, required Widget child, Key? key}) =>
      AnimatedBuilder(
        animation: _pulse,
        child: child,
        builder: (_, icon) => DecoratedBox(
          key: key,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: count > 0
                ? [
                    BoxShadow(
                      color: _gold.withValues(alpha: .1 + _pulse.value * .22),
                      blurRadius: 10 + _pulse.value * 9,
                    ),
                  ]
                : null,
          ),
          child: Badge(
            isLabelVisible: count > 0,
            backgroundColor: _gold,
            textColor: const Color(0xFF20170D),
            label: Text(count > 99 ? '99+' : '$count'),
            child: icon,
          ),
        ),
      );

  PopupMenuItem<_Destination> _item(
    _Destination value,
    IconData icon,
    String title,
    String detail,
    int count,
  ) => PopupMenuItem(
    value: value,
    height: 68,
    child: Row(
      children: [
        _news(
          count: count,
          child: Icon(icon, color: _gold, size: 24),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                detail,
                style: const TextStyle(fontSize: 11, color: Colors.white60),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final nickname = _social.nickname ?? 'Mon profil';
    final menuNews =
        _social.friendRequests + _social.invitations + _social.challengeRewards;
    final packNews = _packNews.length;
    return AppBar(
      toolbarHeight: widget.preferredSize.height,
      leadingWidth: 48,
      titleSpacing: 2,
      backgroundColor: const Color(0xFF101A23),
      shape: const Border(
        bottom: BorderSide(color: Color(0xFF50432E), width: .6),
      ),
      leading: IconButton(
        tooltip: 'Communauté',
        icon: const Icon(Icons.groups_outlined),
        onPressed: () => _open(const CommunityScreen()),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey('home-profile'),
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _open(
                    _social.nickname != null
                        ? const SocialProfileScreen()
                        : const CommunityScreen(),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        RepaintBoundary(
                          child: PlayerAvatar(
                            key: const ValueKey('home-equipped-avatar'),
                            avatar: _social.avatar,
                            nickname: nickname == 'Mon profil' ? '' : nickname,
                            size: 48,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'MON VILLAGE',
                                style: TextStyle(
                                  color: _gold,
                                  fontSize: 8,
                                  letterSpacing: .6,
                                ),
                              ),
                              Text(
                                nickname,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          PopupMenuButton<_Destination>(
            key: const ValueKey('home-menu'),
            tooltip: menuNews > 0
                ? 'Menu · $menuNews nouveauté(s)'
                : 'Menu du village',
            position: PopupMenuPosition.under,
            offset: const Offset(0, 8),
            constraints: const BoxConstraints(minWidth: 272, maxWidth: 320),
            color: const Color(0xFF17252F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFF675332)),
            ),
            popUpAnimationStyle: AnimationStyle(
              duration: _reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              reverseDuration: _reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
            ),
            onOpened: () => setState(() => _menuOpen = true),
            onCanceled: () => setState(() => _menuOpen = false),
            onSelected: _select,
            icon: _news(
              count: menuNews,
              key: const ValueKey('home-menu-news'),
              child: AnimatedRotation(
                turns: _menuOpen ? .5 : 0,
                duration: _reduced
                    ? Duration.zero
                    : const Duration(milliseconds: 230),
                child: const Icon(Icons.expand_more_rounded, color: _gold),
              ),
            ),
            itemBuilder: (_) => [
              _item(
                _Destination.store,
                Icons.storefront_outlined,
                'Boutique',
                'Collections & Collectionneur',
                0,
              ),
              _item(
                _Destination.friends,
                Icons.people_outline,
                'Mon cercle',
                'Amis, profils & discussions',
                _social.friendRequests,
              ),
              _item(
                _Destination.invitations,
                Icons.mark_email_unread_outlined,
                'Invitations',
                'Rejoindre vos amis au village',
                _social.invitations,
              ),
              _item(
                _Destination.challenges,
                Icons.emoji_events_outlined,
                'Défis',
                'Progrès & cadeaux à réclamer',
                _social.challengeRewards,
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: packNews > 0
              ? 'Mes téléchargements · $packNews pack(s) à compléter'
              : 'Mes téléchargements',
          icon: _news(
            count: packNews,
            key: const ValueKey('home-download-news'),
            child: const Icon(Icons.download_for_offline_outlined),
          ),
          onPressed: () => _open(const DownloadsScreen()),
        ),
        const AudioSettingsButton(),
        const SizedBox(width: 4),
      ],
    );
  }
}
