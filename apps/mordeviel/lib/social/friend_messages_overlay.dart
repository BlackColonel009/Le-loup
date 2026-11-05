import 'dart:async';
import 'package:flutter/material.dart';
import '../profile/player_avatar.dart';
import 'friend_messages_service.dart';
import 'private_chat_screen.dart';
import 'social_api.dart';
import 'social_notifications.dart';
import '../community/community_screen.dart';

class FriendMessagesOverlay extends StatefulWidget {
  const FriendMessagesOverlay({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.service,
  });
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final FriendMessagesService? service;
  @override
  State<FriendMessagesOverlay> createState() => _FriendMessagesOverlayState();
}

class _FriendMessagesOverlayState extends State<FriendMessagesOverlay> {
  late final _messages = widget.service ?? FriendMessagesService.instance;
  bool _expanded = false, _opening = false;
  final _drag = <int, double>{};
  @override
  void initState() {
    super.initState();
    if (widget.service == null) _messages.start();
    pendingSocialNotification.addListener(_notification);
    WidgetsBinding.instance.addPostFrameCallback((_) => _notification());
  }

  @override
  void dispose() {
    pendingSocialNotification.removeListener(_notification);
    if (widget.service == null) _messages.stop();
    super.dispose();
  }

  void _notification() {
    final payload = pendingSocialNotification.value;
    if (payload == null || !payload.startsWith('chat:')) return;
    final id = int.tryParse(payload.substring(5));
    pendingSocialNotification.value = null;
    if (id == null || id <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_open(id, null));
    });
  }

  Future<void> _open(int id, String? nickname) async {
    if (_opening) return;
    _opening = true;
    try {
      if (id == -1) {
        setState(() => _expanded = false);
        await widget.navigatorKey.currentState?.push<void>(
          MaterialPageRoute(builder: (_) => const CommunityScreen()),
        );
        await _messages.refresh();
        return;
      }
      if (nickname == null) {
        final history = await SocialApi.instance.request('/social/chats/$id');
        nickname = (history['friend'] as Map)['nickname'] as String;
      }
      if (!mounted) return;
      setState(() => _expanded = false);
      await widget.navigatorKey.currentState?.push<void>(
        MaterialPageRoute(
          builder: (_) => PrivateChatScreen(friendId: id, nickname: nickname!),
        ),
      );
      await _messages.refresh();
    } catch (_) {
      // A deleted friendship or expired login is handled in the social pages.
    } finally {
      _opening = false;
    }
  }

  Widget _avatar(Map<String, dynamic> message, {bool pile = false}) {
    final id = message['friend_id'] as int;
    return GestureDetector(
      key: ValueKey('friend-alert-$id'),
      onHorizontalDragStart: (_) => _drag[id] = 0,
      onHorizontalDragUpdate: (details) =>
          _drag[id] = (_drag[id] ?? 0) + details.delta.dx,
      onHorizontalDragEnd: (details) {
        if ((_drag.remove(id) ?? 0) < -24 ||
            (details.primaryVelocity ?? 0) < -100) {
          _messages.dismiss(id);
        }
      },
      child: Material(
        color: const Color(0xFF18232E),
        shape: const CircleBorder(),
        elevation: 8,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: pile
              ? () => setState(() => _expanded = true)
              : () => _open(id, message['nickname'] as String),
          child: Semantics(
            label:
                '${message['nickname']} · ${message['unread_count']} message(s)',
            button: true,
            child: Badge(
              label: Text('${message['unread_count']}'),
              backgroundColor: const Color(0xFFE1BA78),
              textColor: const Color(0xFF18232E),
              child: id == -1
                  ? const SizedBox(
                      width: 52,
                      height: 52,
                      child: Icon(Icons.forum, color: Color(0xFFE1BA78)),
                    )
                  : PlayerAvatar(
                      avatar: message['avatar'] as Map?,
                      nickname: message['nickname'] as String,
                      size: 52,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      ListenableBuilder(
        listenable: _messages,
        builder: (context, _) {
          final alerts = _messages.alerts;
          if (alerts.isEmpty) return const SizedBox.shrink();
          final screen = MediaQuery.sizeOf(context);
          final usableHeight =
              screen.height - MediaQuery.viewInsetsOf(context).bottom;
          final top = (usableHeight * .22).clamp(
            MediaQuery.paddingOf(context).top + 80,
            screen.height * .45,
          );
          final preview = _messages.preview;
          return Positioned(
            left: MediaQuery.paddingOf(context).left + 10,
            top: top,
            child: SizedBox(
              width: (screen.width - 24).clamp(100, 350),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSize(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 230),
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: _expanded ? 78 : 64,
                      height: _expanded
                          ? (alerts.length * 88.0 + 30).clamp(
                              90,
                              (usableHeight - top - 35).clamp(90, 480),
                            )
                          : alerts.length > 1
                          ? 86
                          : 64,
                      child: _expanded
                          ? Column(
                              children: [
                                SizedBox(
                                  height: 28,
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(
                                      Icons.expand_less,
                                      color: Color(0xFFE1BA78),
                                      semanticLabel: 'Replier les messages',
                                    ),
                                    onPressed: () =>
                                        setState(() => _expanded = false),
                                  ),
                                ),
                                Expanded(
                                  child: ListView(
                                    padding: const EdgeInsets.only(
                                      top: 8,
                                      right: 8,
                                      bottom: 4,
                                    ),
                                    children: [
                                      for (final message in alerts)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 16,
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _avatar(message),
                                              const SizedBox(height: 4),
                                              Text(
                                                message['nickname'] as String,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Color(0xFFF2E8D5),
                                                  shadows: [
                                                    Shadow(
                                                      color: Colors.black,
                                                      blurRadius: 4,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Stack(
                              clipBehavior: Clip.none,
                              children: [
                                for (
                                  var i =
                                      (alerts.length > 3 ? 3 : alerts.length) -
                                      1;
                                  i >= 0;
                                  i--
                                )
                                  Positioned(
                                    left: i * 3,
                                    top: i * 11,
                                    child: _avatar(
                                      alerts[i],
                                      pile: alerts.length > 1,
                                    ),
                                  ),
                              ],
                            ),
                    ),
                  ),
                  if (preview != null)
                    Expanded(
                      child: _MessagePreview(
                        key: ValueKey('message-preview-${preview['last_id']}'),
                        message: preview,
                        onOpen: () => _open(
                          preview['friend_id'] as int,
                          preview['nickname'] as String,
                        ),
                        onExpired: () =>
                            _messages.expirePreview(preview['last_id'] as int),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    ],
  );
}

class _MessagePreview extends StatelessWidget {
  const _MessagePreview({
    super.key,
    required this.message,
    required this.onOpen,
    required this.onExpired,
  });
  final Map<String, dynamic> message;
  final VoidCallback onOpen, onExpired;
  @override
  Widget build(BuildContext context) => Material(
    elevation: 10,
    color: const Color(0xFF1B2A35),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message['nickname'] as String,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFFE1BA78),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              (message['text'] as String).startsWith('[[sticker:')
                  ? 'Sticker reçu'
                  : message['text'] as String,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: Color(0xFFF2E8D5)),
            ),
            const SizedBox(height: 9),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1, end: 0),
              duration: const Duration(seconds: 5),
              onEnd: onExpired,
              builder: (_, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 3,
                color: const Color(0xFFE1BA78),
                backgroundColor: Colors.white12,
                semanticsLabel: 'Durée de l’aperçu du message',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
