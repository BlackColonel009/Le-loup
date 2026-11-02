import 'dart:async';
import 'package:flutter/material.dart';
import '../design/game_theme.dart';
import 'attention_surface.dart';
import 'village_guidance.dart';
export 'village_guidance.dart' show VillageDestination;

class VillageNavigation extends StatefulWidget {
  const VillageNavigation({
    super.key,
    required this.destination,
    required this.phase,
    required this.isHost,
    required this.code,
    required this.onSelect,
    required this.onCodex,
    required this.village,
    required this.chat,
    required this.actions,
    required this.preparation,
    this.banner,
    this.audioControl,
    this.voiceControl,
    this.room,
    this.privateState,
    this.selfId,
    this.connected = true,
    this.onRoleCard,
  });
  final VillageDestination destination;
  final String phase, code;
  final bool isHost, connected;
  final String? selfId;
  final Map<String, dynamic>? room, privateState;
  final ValueChanged<VillageDestination> onSelect;
  final VoidCallback onCodex;
  final VoidCallback? onRoleCard;
  final Widget village, chat, actions, preparation;
  final Widget? banner, audioControl, voiceControl;
  static const titles = {
    VillageDestination.village: 'Le village',
    VillageDestination.council: 'Conseil du village',
    VillageDestination.chat: 'Discussions',
    VillageDestination.actions: 'Actions de la partie',
    VillageDestination.preparation: 'Habitants et préparation',
  };
  static const icons = [
    Icons.cottage_outlined,
    Icons.groups_outlined,
    Icons.chat_bubble_outline,
    Icons.nights_stay_outlined,
    Icons.tune,
  ];
  @override
  State<VillageNavigation> createState() => _VillageNavigationState();
}

class _VillageNavigationState extends State<VillageNavigation> {
  final _tabs = GlobalKey<_CouncilTabsState>();
  final _bondClock = Stopwatch();
  Timer? _bondTimer;
  final _counts = <String, int>{}, _unread = <String, int>{};
  final _tails = <String, String>{};
  bool _discussion = true;
  bool get _day =>
      ['day', 'mayor_election', 'voting', 'vote_result'].contains(widget.phase);
  bool get _ballot =>
      ['mayor_election', 'voting', 'vote_result'].contains(widget.phase);
  Map get _room =>
      widget.room ??
      {'phase': widget.phase, 'players': const [], 'game': const {}};
  int get _bondRemaining =>
      (((widget.privateState?['bond_chat'] as Map?)?['remaining_ms'] as int? ??
                  0) -
              ((widget.privateState?['bond_chat'] as Map?)?['open'] == true
                  ? _bondClock.elapsedMilliseconds
                  : 0))
          .clamp(0, 60000);
  @override
  void initState() {
    super.initState();
    _discussion = !_ballot;
    _syncBond();
  }

  void _syncBond() {
    _bondClock
      ..reset()
      ..start();
    _bondTimer?.cancel();
    if (widget.privateState?['bond_chat'] != null) {
      _bondTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {});
        if (_bondRemaining == 0) timer.cancel();
      });
    }
  }

  @override
  void didUpdateWidget(VillageNavigation old) {
    super.didUpdateWidget(old);
    if (old.phase != widget.phase) _discussion = !_ballot;
    if (old.privateState?['bond_chat'] != widget.privateState?['bond_chat']) {
      _syncBond();
    }
  }

  @override
  void dispose() {
    _bondTimer?.cancel();
    _bondClock.stop();
    super.dispose();
  }

  void _go(VillageDestination target) {
    if (target == VillageDestination.council && _ballot) {
      _discussion = false;
      _tabs.currentState?.showVote();
    }
    widget.onSelect(target);
  }

  int _track(VillageChannel channel) {
    if (!channel.available) return 0;
    final total = channel.messages.length;
    final last = total == 0
        ? ''
        : '${channel.messages.last['author']}:${channel.messages.last['text']}';
    final previous = _counts[channel.scope] ?? 0;
    final added = total > previous
        ? total - previous
        : total == previous && last != _tails[channel.scope] && total > 0
        ? 1
        : 0;
    _unread[channel.scope] = (_unread[channel.scope] ?? 0) + added;
    _counts[channel.scope] = total;
    _tails[channel.scope] = last;
    if (widget.destination == VillageDestination.chat ||
        widget.destination == VillageDestination.council &&
            _day &&
            _discussion) {
      _unread[channel.scope] = 0;
    }
    return _unread[channel.scope] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final channel = VillageChannel.resolve(
      _room,
      widget.privateState,
      isHost: widget.isHost,
      connected: widget.connected,
      bondRemaining: _bondRemaining,
    );
    final guidance = VillageGuidance.resolve(
      _room,
      widget.privateState,
      isHost: widget.isHost,
      connected: widget.connected,
      channel: channel,
      selfId: widget.selfId,
    );
    final unread = _track(channel);
    final wolvesChoice =
        channel.kind == 'wolves' &&
        !widget.isHost &&
        widget.privateState?['can_act'] == true &&
        !((widget.privateState?['choices'] as Map?)?.containsKey(
              widget.selfId ?? widget.privateState?['id'],
            ) ??
            false);
    final actionPending =
        guidance.attention &&
            guidance.destination == VillageDestination.actions ||
        wolvesChoice;
    final votePending =
        guidance.attention &&
        guidance.destination == VillageDestination.council;
    final token =
        '${(_room['game'] as Map?)?['phase_revision']}:${guidance.title}:$unread';
    Widget content;
    if (widget.destination == VillageDestination.council && _day) {
      content = _CouncilTabs(
        key: _tabs,
        ballot: _ballot,
        votePending: votePending,
        unread: unread,
        chat: widget.chat,
        actions: widget.actions,
        onDiscussion: (value) {
          if (mounted && _discussion != value) {
            setState(() => _discussion = value);
          }
        },
      );
    } else if (widget.destination == VillageDestination.council &&
        [
          'hunter',
          'scapegoat',
          'mayor_succession',
          'mediation',
          'ended',
        ].contains(widget.phase)) {
      content = widget.actions;
    } else if (widget.destination == VillageDestination.council) {
      content = Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.nights_stay_outlined,
                size: 48,
                color: GameTheme.gold,
              ),
              const SizedBox(height: 16),
              Text(
                'Le conseil se réunit au lever du jour',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 10),
              const Text(
                'Pendant la nuit, suis ton appel dans Actions. Les chats privés s’affichent seulement quand tu peux y accéder.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => _go(VillageDestination.actions),
                child: const Text('Voir la phase en cours'),
              ),
              if (channel.private)
                TextButton.icon(
                  onPressed: () => _go(VillageDestination.chat),
                  icon: const Icon(Icons.lock_open_outlined),
                  label: Text(
                    channel.kind == 'wolves'
                        ? 'Rejoindre la meute'
                        : 'Rejoindre mon échange privé',
                  ),
                ),
            ],
          ),
        ),
      );
    } else {
      content = switch (widget.destination) {
        VillageDestination.village => widget.village,
        VillageDestination.chat => widget.chat,
        VillageDestination.preparation => widget.preparation,
        _ => widget.actions,
      };
    }
    final menu = PopupMenuButton<VillageDestination>(
      tooltip: 'Menu du village',
      initialValue: widget.destination,
      onSelected: _go,
      itemBuilder: (context) => [
        for (final item in VillageDestination.values)
          PopupMenuItem(
            value: item,
            child: Row(
              children: [
                Icon(
                  VillageNavigation.icons[item.index],
                  size: 22,
                  color: item == widget.destination
                      ? GameTheme.gold
                      : GameTheme.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item == VillageDestination.actions && widget.isHost
                        ? 'Table du MDJ'
                        : VillageNavigation.titles[item]!,
                  ),
                ),
                if (item == widget.destination)
                  const Icon(Icons.check, size: 18, color: GameTheme.gold),
              ],
            ),
          ),
      ],
      icon: const Icon(Icons.more_horiz),
    );
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, box) {
          final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
          final compact = box.maxHeight < 460;
          final crowded = box.maxHeight < 270;
          final chatTitle = channel.kind == 'wolves'
              ? 'Meute'
              : channel.private
              ? 'Privé'
              : 'Chats';
          final hintTarget =
              wolvesChoice && widget.destination == VillageDestination.chat
              ? VillageDestination.actions
              : guidance.destination;
          final hintLabel =
              wolvesChoice && widget.destination == VillageDestination.chat
              ? 'Choisir ma cible dans Actions'
              : guidance.button;
          void hintTap() {
            if (guidance.card && widget.onRoleCard != null) {
              widget.onRoleCard!();
            } else {
              _go(hintTarget);
            }
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 6, 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.destination == VillageDestination.chat
                                ? channel.title
                                : VillageNavigation.titles[widget.destination]!,
                            maxLines: compact ? 1 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontSize: compact ? 21 : 25),
                          ),
                          if (!crowded)
                            Text(
                              'Salon ${widget.code} · ${widget.phase == 'lobby'
                                  ? 'Préparation'
                                  : _day
                                  ? 'Jour'
                                  : widget.phase == 'ended'
                                  ? 'Partie terminée'
                                  : 'Nuit'}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    if (widget.onRoleCard != null)
                      IconButton(
                        tooltip: 'Ma carte secrète',
                        onPressed: widget.onRoleCard,
                        icon: const Icon(Icons.style_outlined),
                      ),
                    IconButton(
                      tooltip: 'Codex et règles',
                      onPressed: widget.onCodex,
                      icon: const Icon(Icons.menu_book_outlined),
                    ),
                    ?widget.audioControl,
                    menu,
                  ],
                ),
              ),
              if (!crowded && !keyboard)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                  child: AttentionSurface(
                    active: guidance.attention,
                    token: token,
                    color: guidance.confirmed
                        ? const Color(0xFF77C5A6)
                        : GameTheme.gold,
                    child: Material(
                      color: guidance.confirmed
                          ? const Color(0xFF1B342D)
                          : GameTheme.panel,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: hintTap,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                guidance.confirmed
                                    ? Icons.check_circle_outline
                                    : guidance.attention
                                    ? Icons.touch_app_outlined
                                    : Icons.explore_outlined,
                                color: guidance.confirmed
                                    ? const Color(0xFF77C5A6)
                                    : GameTheme.gold,
                                size: 23,
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      guidance.title,
                                      maxLines: 2,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (!compact)
                                      Text(
                                        guidance.detail,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(fontSize: 12),
                                      ),
                                    Text(
                                      hintLabel,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: GameTheme.gold,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: GameTheme.gold,
                                size: 19,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (!crowded && !keyboard && widget.banner != null)
                widget.banner!,
              Expanded(
                key: const ValueKey('village-current-page'),
                child: content,
              ),
              if (!keyboard && !crowded && widget.voiceControl != null)
                widget.voiceControl!,
              Material(
                color: GameTheme.ink,
                child: Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: GameTheme.line, width: .5),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  child: Row(
                    children: [
                      _destination(
                        VillageDestination.village,
                        'Village',
                        Icons.cottage_outlined,
                        compact: compact || keyboard,
                        token: token,
                      ),
                      _destination(
                        VillageDestination.council,
                        'Conseil',
                        Icons.groups_outlined,
                        pending: votePending,
                        badge: _day ? unread : 0,
                        compact: compact || keyboard,
                        token: token,
                      ),
                      _destination(
                        VillageDestination.chat,
                        chatTitle,
                        channel.private
                            ? Icons.lock_open_outlined
                            : Icons.forum_outlined,
                        pending:
                            unread > 0 ||
                            channel.private &&
                                widget.destination != VillageDestination.chat,
                        badge: unread,
                        privateOpen: channel.private,
                        compact: compact || keyboard,
                        token: token,
                      ),
                      _destination(
                        widget.phase == 'lobby'
                            ? VillageDestination.preparation
                            : VillageDestination.actions,
                        widget.phase == 'lobby'
                            ? 'Préparation'
                            : widget.isHost
                            ? 'MDJ'
                            : 'Actions',
                        widget.phase == 'lobby'
                            ? Icons.tune
                            : Icons.touch_app_outlined,
                        pending: actionPending,
                        compact: compact || keyboard,
                        token: token,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _destination(
    VillageDestination target,
    String label,
    IconData icon, {
    bool pending = false,
    int badge = 0,
    bool privateOpen = false,
    required bool compact,
    required Object token,
  }) {
    final selected = target == widget.destination;
    final color = selected || pending
        ? GameTheme.gold
        : privateOpen
        ? const Color(0xFF77C5A6)
        : GameTheme.muted;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: AttentionSurface(
          active: pending,
          token: token,
          radius: 13,
          child: Material(
            color: selected ? const Color(0xFF333B32) : Colors.transparent,
            borderRadius: BorderRadius.circular(13),
            child: InkWell(
              key: ValueKey('village-nav-${target.name}'),
              onTap: () => _go(target),
              borderRadius: BorderRadius.circular(13),
              child: Semantics(
                selected: selected,
                button: true,
                label:
                    '$label${badge > 0
                        ? ', $badge nouveaux messages'
                        : pending
                        ? ', action disponible'
                        : ''}',
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: compact ? 50 : 62),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 5,
                      horizontal: 3,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(icon, size: 23, color: color),
                            if (badge > 0 || pending || privateOpen)
                              Positioned(
                                right: badge > 0 ? -16 : -4,
                                top: -3,
                                child: Container(
                                  padding: badge > 0
                                      ? const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        )
                                      : EdgeInsets.zero,
                                  constraints: BoxConstraints(
                                    minWidth: badge > 0 ? 17 : 7,
                                    minHeight: badge > 0 ? 15 : 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: badge > 0 || pending
                                        ? GameTheme.gold
                                        : const Color(0xFF77C5A6),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: badge > 0
                                      ? Text(
                                          badge > 99 ? '99+' : '$badge',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: GameTheme.ink,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          label,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: color,
                          ),
                        ),
                      ],
                    ),
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

class _CouncilTabs extends StatefulWidget {
  const _CouncilTabs({
    super.key,
    required this.ballot,
    required this.votePending,
    required this.unread,
    required this.chat,
    required this.actions,
    required this.onDiscussion,
  });
  final bool ballot, votePending;
  final int unread;
  final Widget chat, actions;
  final ValueChanged<bool> onDiscussion;
  @override
  State<_CouncilTabs> createState() => _CouncilTabsState();
}

class _CouncilTabsState extends State<_CouncilTabs>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.ballot ? 1 : 0,
  )..addListener(_changed);
  void _changed() {
    widget.onDiscussion(_tabs.index == 0);
  }

  void showVote() => _tabs.animateTo(1);
  @override
  void didUpdateWidget(_CouncilTabs old) {
    super.didUpdateWidget(old);
    if (old.ballot != widget.ballot) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tabs.animateTo(widget.ballot ? 1 : 0);
      });
    }
  }

  @override
  void dispose() {
    _tabs.removeListener(_changed);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: TabBar(
          controller: _tabs,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: const Color(0xFF354038),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: GameTheme.gold, width: .7),
          ),
          labelColor: GameTheme.ivory,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.forum_outlined, size: 19),
                  const SizedBox(width: 6),
                  const Flexible(child: Text('Discussion')),
                  if (widget.unread > 0)
                    Padding(
                      padding: const EdgeInsets.only(left: 5),
                      child: Text(
                        '${widget.unread}',
                        style: const TextStyle(color: GameTheme.gold),
                      ),
                    ),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.how_to_vote_outlined,
                    size: 19,
                    color: widget.votePending ? GameTheme.gold : null,
                  ),
                  const SizedBox(width: 6),
                  const Flexible(child: Text('Réunion et vote')),
                  if (widget.votePending)
                    const Padding(
                      padding: EdgeInsets.only(left: 5),
                      child: Icon(Icons.circle, size: 7, color: GameTheme.gold),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: TabBarView(
          controller: _tabs,
          children: [widget.chat, widget.actions],
        ),
      ),
    ],
  );
}
