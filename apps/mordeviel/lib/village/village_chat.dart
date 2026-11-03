import 'dart:async';
import 'package:flutter/material.dart';
import 'package:local_host/local_host.dart' show stickerMessage;
import '../design/game_theme.dart';
import '../stickers/chat_stickers.dart';
import '../chat/message_reply.dart';
import '../stickers/sticker_suggestions.dart';
import 'package:local_host/local_host.dart' show ChatSticker;
import 'village_guidance.dart';

class VillageChat extends StatefulWidget {
  const VillageChat({
    super.key,
    this.fullPage = false,
    required this.room,
    this.privateState,
    required this.isHost,
    required this.connected,
    required this.onSend,
    this.selfId,
  });
  final bool fullPage, isHost, connected;
  final Map<String, dynamic> room;
  final Map<String, dynamic>? privateState;
  final String? selfId;
  final void Function(
    String action,
    int revision,
    String text, {
    String? replyTo,
  })
  onSend;
  @override
  State<VillageChat> createState() => _VillageChatState();
}

class _VillageChatState extends State<VillageChat> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  Map? _reply;
  final _bondClock = Stopwatch();
  Timer? _bondTicker;
  Map? get _bond => widget.privateState?['bond_chat'] as Map?;
  int get _bondRemaining =>
      ((_bond?['remaining_ms'] as int? ?? 0) -
              (_bond?['open'] == true ? _bondClock.elapsedMilliseconds : 0))
          .clamp(0, 60000);
  VillageChannel get _channel => VillageChannel.resolve(
    widget.room,
    widget.privateState,
    isHost: widget.isHost,
    connected: widget.connected,
    bondRemaining: _bondRemaining,
  );
  bool get _canReact => (widget.room['features'] as List? ?? const []).contains(
    'house_reactions',
  );
  @override
  void initState() {
    super.initState();
    _syncBond();
  }

  void _syncBond() {
    _bondClock
      ..reset()
      ..start();
    _bondTicker?.cancel();
    if (_bond != null) {
      _bondTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {});
        if (_bondRemaining == 0) timer.cancel();
      });
    }
  }

  @override
  void didUpdateWidget(VillageChat old) {
    super.didUpdateWidget(old);
    if (old.privateState?['bond_chat'] != _bond) _syncBond();
    final previousChannel = VillageChannel.resolve(
      old.room,
      old.privateState,
      isHost: old.isHost,
      connected: old.connected,
    );
    if (previousChannel.scope != _channel.scope) {
      _text.clear();
      _reply = null;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    _bondTicker?.cancel();
    _bondClock.stop();
    super.dispose();
  }

  String get _command => switch (_channel.kind) {
    'day' => 'day.chat',
    'wolves' => 'wolves.chat',
    _ => 'bond.chat',
  };
  void _send() {
    if (!_channel.writable || _text.text.trim().isEmpty) return;
    widget.onSend(
      _command,
      (widget.room['game'] as Map)['phase_revision'] as int,
      _text.text.trim(),
      replyTo: _reply?['id'] as String?,
    );
    _text.clear();
    setState(() => _reply = null);
  }

  Future<void> _sticker({bool reaction = false, ChatSticker? suggested}) async {
    if (suggested == null) _focus.unfocus();
    final scope = _channel.scope;
    final sticker = suggested ?? await showStickerPicker(context);
    if (!mounted ||
        sticker == null ||
        !_channel.writable ||
        scope != _channel.scope) {
      return;
    }
    widget.onSend(
      reaction ? 'reaction.send' : _command,
      (widget.room['game'] as Map)['phase_revision'] as int,
      stickerMessage(sticker),
      replyTo: reaction ? null : _reply?['id'] as String?,
    );
    if (!reaction) setState(() => _reply = null);
  }

  String _name(dynamic id) => id == 'unknown'
      ? 'Présence inconnue'
      : (widget.room['players'] as List? ?? const [])
                .where((p) => p['id'] == id)
                .map((p) => p['nickname'] as String)
                .firstOrNull ??
            'Joueur';
  @override
  Widget build(BuildContext context) {
    final channel = _channel;
    final spectator = !widget.isHost && widget.privateState?['alive'] == false;
    final paused = (widget.room['game'] as Map?)?['paused'] == true;
    final status = !widget.connected
        ? 'Hors ligne'
        : paused
        ? 'Pause'
        : spectator
        ? 'Spectateur'
        : widget.isHost
        ? 'Lecture MDJ'
        : channel.writable
        ? 'Ouvert'
        : channel.available
        ? 'Lecture'
        : 'Fermé';
    final color = channel.writable ? const Color(0xFF83D4B3) : GameTheme.gold;
    final icon = channel.kind == 'wolves'
        ? Icons.pets_outlined
        : channel.private
        ? Icons.lock_outline
        : channel.available
        ? Icons.forum_outlined
        : Icons.nights_stay_outlined;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: LayoutBuilder(
        builder: (context, size) {
          final compact = size.maxHeight < 290;
          final heading = size.maxHeight < 150
              ? const SizedBox.shrink()
              : Container(
                  margin: const EdgeInsets.only(bottom: 9),
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: compact ? 6 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: GameTheme.panel,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: channel.private
                          ? GameTheme.gold.withValues(alpha: .4)
                          : GameTheme.line.withValues(alpha: .5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            icon,
                            size: compact ? 19 : 24,
                            color: GameTheme.gold,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              channel.title,
                              maxLines: compact ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Cormorant',
                                fontSize: compact ? 20 : 25,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: .1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 10,
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (!compact)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            spectator
                                ? 'Tu suis les débats du jour sans écrire ni voter.'
                                : channel.description,
                            style: const TextStyle(
                              fontSize: 12,
                              color: GameTheme.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(child: heading),
              Expanded(
                child: channel.messages.isEmpty
                    ? LayoutBuilder(
                        builder: (context, box) => Center(
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (box.maxHeight > 100) ...[
                                  Icon(
                                    icon,
                                    size: 38,
                                    color: GameTheme.gold.withValues(
                                      alpha: .65,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                if (box.maxHeight > 35)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Text(
                                      channel.writable
                                          ? channel.private
                                                ? 'Votre échange commence ici.'
                                                : 'Le conseil attend vos premiers mots.'
                                          : 'Aucun message pour le moment.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: GameTheme.muted,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : ListView.builder(
                        key: const PageStorageKey('village-conversation'),
                        reverse: true,
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        itemCount: channel.messages.length,
                        itemBuilder: (context, index) => _message(
                          channel.messages[channel.messages.length - 1 - index]
                              as Map,
                          channel,
                        ),
                      ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: size.maxHeight * .65),
                child: SingleChildScrollView(
                  primary: false,
                  child: Column(
                    key: const ValueKey('village-chat-composer'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (channel.writable) ...[
                        StickerSuggestions(
                          controller: _text,
                          scope: channel.scope,
                          enabled: channel.writable,
                          onSelect: (sticker) => _sticker(suggested: sticker),
                        ),
                        if (_reply != null)
                          MessageReply(
                            reply: {
                              ..._reply!,
                              'sender': _name(_reply!['author']),
                            },
                            onCancel: () => setState(() => _reply = null),
                          ),
                        Container(
                          key: const ValueKey('village-composer-field'),
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            color: GameTheme.panel,
                            borderRadius: BorderRadius.circular(19),
                            border: Border.all(
                              color: GameTheme.gold.withValues(alpha: .5),
                            ),
                          ),
                          child: TextField(
                            key: const ValueKey('village-chat-input'),
                            focusNode: _focus,
                            controller: _text,
                            maxLength: 300,
                            minLines: 1,
                            maxLines: 3,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                              hintText: channel.private
                                  ? 'Ton message privé…'
                                  : 'Ton message au conseil…',
                              counterText: '',
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 9,
                              ),
                              prefixIcon: IconButton(
                                tooltip: 'Stickers',
                                onPressed: () => _sticker(),
                                icon: const Icon(Icons.emoji_emotions_outlined),
                              ),
                              suffixIcon: ValueListenableBuilder(
                                valueListenable: _text,
                                builder: (context, value, _) => TextButton(
                                  onPressed: value.text.trim().isEmpty
                                      ? null
                                      : _send,
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(76, 48),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                  ),
                                  child: const Text('Envoyer'),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_canReact &&
                            !['lovers', 'sisters'].contains(channel.kind))
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => _sticker(reaction: true),
                              icon: const Icon(
                                Icons.add_reaction_outlined,
                                size: 18,
                              ),
                              label: const Text(
                                'Réagir sur ma maison',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.lock_outline,
                                size: 17,
                                color: GameTheme.muted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  !widget.connected
                                      ? 'Reconnecte-toi pour retrouver les échanges.'
                                      : spectator
                                      ? 'Mode spectateur · lecture des échanges du jour.'
                                      : widget.isHost
                                      ? 'Vue du MDJ : lecture des échanges autorisés.'
                                      : paused
                                      ? 'Le MDJ a mis la partie en pause.'
                                      : channel.available
                                      ? 'Le MDJ contrôle l’ouverture de ce canal.'
                                      : 'Suis les appels du MDJ dans Actions.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: GameTheme.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
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

  Widget _message(Map message, VillageChannel channel) {
    final mine =
        message['author'] == (widget.selfId ?? widget.privateState?['id']);
    final name = _name(message['author']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!mine) ...[
                CircleAvatar(
                  radius: 14,
                  backgroundColor: channel.private
                      ? const Color(0xFF423343)
                      : const Color(0xFF344034),
                  child: Text(
                    message['author'] == 'unknown'
                        ? '?'
                        : name.characters.first.toUpperCase(),
                    style: const TextStyle(fontSize: 12, color: GameTheme.gold),
                  ),
                ),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: mine
                        ? const Color(0xFF344536)
                        : const Color(0xFF23303A),
                    border: Border.all(
                      color: mine
                          ? const Color(0xFF677955)
                          : const Color(0xFF3D4C55),
                      width: .6,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(17),
                      topRight: const Radius.circular(17),
                      bottomLeft: Radius.circular(mine ? 17 : 5),
                      bottomRight: Radius.circular(mine ? 5 : 17),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              mine ? 'Toi · $name' : name,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: GameTheme.gold,
                              ),
                            ),
                          ),
                          if (channel.writable && message['id'] != null)
                            IconButton(
                              tooltip: 'Répondre',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.reply, size: 18),
                              onPressed: () {
                                setState(() => _reply = message);
                                _focus.requestFocus();
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      if (message['reply_id'] != null)
                        MessageReply(
                          reply: {
                            'sender': _name(message['reply_author']),
                            'text': message['reply_text'],
                          },
                        ),
                      ChatMessageBody(
                        text: message['text'] as String,
                        selectable: false,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).replyable(
      channel.writable && message['id'] != null
          ? () {
              setState(() => _reply = message);
              _focus.requestFocus();
            }
          : null,
    );
  }
}
