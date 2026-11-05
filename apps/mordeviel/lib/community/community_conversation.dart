import 'package:flutter/material.dart';
import '../social/friend_messages_service.dart';
import '../profile/player_avatar.dart';
import '../profile/avatar_border.dart';
import '../stickers/chat_stickers.dart';
import '../chat/message_reply.dart';
import '../stickers/sticker_suggestions.dart';
import 'package:local_host/local_host.dart' show ChatSticker;

class CommunityConversation extends StatefulWidget {
  const CommunityConversation({
    super.key,
    required this.messages,
    required this.controller,
    required this.onSend,
    required this.onSticker,
    required this.onProfile,
    required this.onReport,
    this.userId,
    this.nickname,
    this.busy = false,
    this.muted = false,
    this.reply,
    this.onReply,
    this.onCancelReply,
    this.onSuggestedSticker,
  });
  final List<Map<String, dynamic>> messages;
  final TextEditingController controller;
  final VoidCallback onSend, onSticker;
  final ValueChanged<int> onProfile, onReport;
  final int? userId;
  final String? nickname;
  final bool busy, muted;
  final Map<String, dynamic>? reply;
  final ValueChanged<Map<String, dynamic>>? onReply;
  final VoidCallback? onCancelReply;
  final ValueChanged<ChatSticker>? onSuggestedSticker;
  @override
  State<CommunityConversation> createState() => _CommunityConversationState();
}

class _CommunityConversationState extends State<CommunityConversation> {
  final _focus = FocusNode();
  TabController? _tabs;
  bool _reading = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tabs = DefaultTabController.maybeOf(context);
    if (!identical(tabs, _tabs)) {
      _tabs?.removeListener(_syncReading);
      _tabs = tabs;
      _tabs?.addListener(_syncReading);
    }
    _syncReading();
  }

  void _syncReading() {
    final visible =
        (_tabs?.index ?? 0) == 0 && (ModalRoute.of(context)?.isCurrent ?? true);
    if (_reading == visible) return;
    _reading = visible;
    if (visible) {
      FriendMessagesService.instance.reading(-1);
    } else {
      FriendMessagesService.instance.leave(-1);
    }
  }

  @override
  void dispose() {
    _tabs?.removeListener(_syncReading);
    if (_reading) FriendMessagesService.instance.leave(-1);
    _focus.dispose();
    super.dispose();
  }

  DateTime _date(Map message) => DateTime.fromMillisecondsSinceEpoch(
    ((message['created'] as num? ?? 0) * 1000).round(),
  ).toLocal();
  String _day(DateTime date) {
    final now = DateTime.now();
    if (DateUtils.isSameDay(now, date)) return 'Aujourd’hui';
    return MaterialLocalizations.of(context).formatMediumDate(date);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) => Column(
      children: [
        Visibility(
          visible: bounds.maxHeight >= 260,
          maintainState: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.forum_outlined,
                  color: Color(0xFFD6AE70),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'La place du village',
                        style: TextStyle(fontFamily: 'Cormorant', fontSize: 25),
                      ),
                      Text(
                        widget.nickname == null
                            ? 'Questions, rencontres et entraide · discussion publique'
                            : 'Bienvenue ${widget.nickname} · discussion publique',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFB5BCBA),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Règles de la communauté',
                  icon: const Icon(Icons.shield_outlined, size: 21),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Le respect du village'),
                      content: const Text(
                        'Évite les insultes et les termes sexuels. Après trois avertissements consécutifs, le chat est restreint pendant trois heures. Pour un problème personnel, contacte le support privé. Appuie sur un portrait pour consulter le profil et ajouter le joueur à tes amis.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Compris'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.muted)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Chat temporairement restreint. Tu peux lire les échanges et contacter le support privé.',
              style: TextStyle(color: Color(0xFFE8BD80)),
            ),
          ),
        Expanded(
          child: widget.messages.isEmpty
              ? const Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.nights_stay_outlined,
                            size: 48,
                            color: Color(0xFFD6AE70),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Le feu du village n’attend que vous.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Cormorant',
                              fontSize: 25,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Lance une discussion, pose ta question ou salue les autres joueurs.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  key: const PageStorageKey('community-conversation'),
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  itemCount: widget.messages.length,
                  itemBuilder: (context, index) {
                    final position = widget.messages.length - 1 - index;
                    final message = widget.messages[position];
                    final day =
                        position == 0 ||
                        !DateUtils.isSameDay(
                          _date(message),
                          _date(widget.messages[position - 1]),
                        );
                    return Column(
                      children: [
                        if (day)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0xFF23303A),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 5,
                                ),
                                child: Text(
                                  _day(_date(message)),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFD6C6A7),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        _bubble(message),
                      ],
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2730),
              border: Border.all(color: const Color(0xFF586052)),
              borderRadius: BorderRadius.circular(22),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: bounds.maxHeight * .55),
              child: SingleChildScrollView(
                reverse: true,
                primary: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.reply != null)
                      MessageReply(
                        reply: {
                          ...widget.reply!,
                          'sender': widget.reply!['nickname'],
                        },
                        onCancel: widget.onCancelReply,
                      ),
                    if (widget.onSuggestedSticker != null)
                      StickerSuggestions(
                        controller: widget.controller,
                        enabled: !widget.busy && !widget.muted,
                        scope: 'community:${widget.userId}',
                        onSelect: widget.onSuggestedSticker!,
                      ),
                    TextField(
                      key: const ValueKey('community-chat-input'),
                      controller: widget.controller,
                      focusNode: _focus,
                      enabled: !widget.muted,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (!widget.busy && !widget.muted) widget.onSend();
                      },
                      decoration: InputDecoration(
                        hintText: 'Ton message au village…',
                        counterText: '',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        prefixIcon: IconButton(
                          tooltip: 'Stickers',
                          onPressed: widget.busy || widget.muted
                              ? null
                              : () {
                                  _focus.unfocus();
                                  widget.onSticker();
                                },
                          icon: const Icon(Icons.emoji_emotions_outlined),
                        ),
                        suffixIcon: ValueListenableBuilder(
                          valueListenable: widget.controller,
                          builder: (context, value, _) => IconButton.filled(
                            tooltip: 'Envoyer',
                            onPressed:
                                widget.busy ||
                                    widget.muted ||
                                    value.text.trim().isEmpty
                                ? null
                                : widget.onSend,
                            icon: widget.busy
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.arrow_upward, size: 21),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _bubble(Map<String, dynamic> message) {
    final mine = widget.userId != null && widget.userId == message['user_id'];
    final uid = message['user_id'] as int?;
    void profile() {
      if (uid != null) widget.onProfile(uid);
    }

    void respond() {
      widget.onReply?.call(message);
      _focus.requestFocus();
    }

    final portrait = Semantics(
      button: true,
      label: 'Voir le profil de ${message['nickname']}',
      child: InkWell(
        onTap: uid == null ? null : profile,
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: PlayerAvatar(
            avatar: message['avatar'] as Map?,
            nickname: message['nickname'] as String,
            size: 42,
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: mine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!mine) ...[portrait, const SizedBox(width: 9)],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 520),
              padding: const EdgeInsets.fromLTRB(13, 8, 11, 9),
              decoration: BoxDecoration(
                color: mine ? const Color(0xFF384536) : const Color(0xFF23303A),
                border: Border.all(
                  color: mine
                      ? const Color(0xFF62714D)
                      : const Color(0xFF354652),
                  width: .6,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(mine ? 18 : 5),
                  bottomRight: Radius.circular(mine ? 5 : 18),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: InkWell(
                          onTap: uid == null ? null : profile,
                          child: Text(
                            mine ? 'Toi' : message['nickname'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFFE3C58C),
                            ),
                          ),
                        ),
                      ),
                      if ((message['avatar'] as Map?)?['is_creator'] == true)
                        const Padding(
                          padding: EdgeInsets.only(left: 5),
                          child: CreatorBadge(compact: true),
                        )
                      else if (message['role'] == 'admin')
                        const Padding(
                          padding: EdgeInsets.only(left: 5),
                          child: Tooltip(
                            message: 'Administrateur certifié',
                            child: Icon(
                              Icons.verified,
                              size: 15,
                              color: Color(0xFFD6AE70),
                            ),
                          ),
                        ),
                      const SizedBox(width: 10),
                      SizedBox.square(
                        dimension: 28,
                        child: PopupMenuButton<String>(
                          tooltip: 'Options du message',
                          padding: EdgeInsets.zero,
                          iconSize: 17,
                          onSelected: (choice) {
                            if (choice == 'reply') {
                              respond();
                            }
                            if (choice == 'profile') profile();
                            if (choice == 'report') {
                              widget.onReport(message['id'] as int);
                            }
                          },
                          itemBuilder: (_) => [
                            if (!widget.muted && widget.onReply != null)
                              const PopupMenuItem(
                                value: 'reply',
                                child: Text('Répondre'),
                              ),
                            if (uid != null)
                              const PopupMenuItem(
                                value: 'profile',
                                child: Text(
                                  'Voir le profil et les options d’amitié',
                                ),
                              ),
                            if (!mine)
                              const PopupMenuItem(
                                value: 'report',
                                child: Text('Signaler ce message'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (message['reply'] is Map)
                    MessageReply(reply: message['reply'] as Map),
                  ChatMessageBody(
                    text: message['text'] as String,
                    selectable: false,
                  ),
                  const SizedBox(height: 5),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      MaterialLocalizations.of(context).formatTimeOfDay(
                        TimeOfDay.fromDateTime(_date(message)),
                        alwaysUse24HourFormat: true,
                      ),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFFAEB9B5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (mine) ...[const SizedBox(width: 9), portrait],
        ],
      ),
    ).replyable(!widget.muted && widget.onReply != null ? respond : null);
  }
}
