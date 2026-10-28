import 'package:flutter/material.dart';
import 'package:local_host/local_host.dart' show stickerMessage;
import '../stickers/chat_stickers.dart';

class VillageChat extends StatefulWidget {
  const VillageChat({
    super.key,
    this.fullPage = false,
    required this.room,
    this.privateState,
    required this.isHost,
    required this.connected,
    required this.onSend,
  });
  final bool fullPage;
  final Map<String, dynamic> room;
  final Map<String, dynamic>? privateState;
  final bool isHost;
  final bool connected;
  final void Function(String action, int revision, String text) onSend;
  @override
  State<VillageChat> createState() => _VillageChatState();
}

class _VillageChatState extends State<VillageChat> {
  final _text = TextEditingController();
  bool get _day =>
      ['day', 'voting', 'vote_result'].contains(widget.room['phase']);
  bool get _pack =>
      widget.room['phase'] == 'wolves' &&
      (widget.isHost ||
          (widget.privateState?['is_pack'] == true ||
                  widget.privateState?['role'] == 'werewolf') &&
              widget.privateState?['alive'] == true);
  bool get _writable =>
      widget.connected &&
      !widget.isHost &&
      widget.privateState?['alive'] == true &&
      (_day && (widget.room['game'] as Map?)?['chat_open'] == true ||
          _pack && widget.privateState?['can_act'] == true);
  Future<void> _selectSticker() async {
    final sticker = await showStickerPicker(context);
    if (!mounted || sticker == null || !_writable) return;
    widget.onSend(
      _day ? 'day.chat' : 'wolves.chat',
      (widget.room['game'] as Map)['phase_revision'] as int,
      stickerMessage(sticker),
    );
  }

  @override
  void didUpdateWidget(covariant VillageChat oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room['phase'] != widget.room['phase']) _text.clear();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.room['game'] as Map?;
    final day = _day, pack = _pack;
    List messages = [];
    if (day) {
      messages = game?['day_messages'] as List? ?? [];
    } else if (pack && widget.isHost) {
      messages =
          (widget.room['game_host'] as Map?)?['wolf_messages'] as List? ?? [];
    } else if (pack) {
      messages = widget.privateState?['messages'] as List? ?? [];
    }
    final writable = _writable;
    String name(dynamic id) =>
        (widget.room['players'] as List)
            .where((p) => p['id'] == id)
            .map((p) => p['nickname'] as String)
            .firstOrNull ??
        'Joueur';
    Widget messageRow(int i) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF202B34),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF806747)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name(messages[i]['author']),
            style: const TextStyle(
              color: Color(0xFFE1BB80),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          ChatMessageBody(text: messages[i]['text'] as String),
        ],
      ),
    );
    final heading = <Widget>[
      if (!widget.isHost && widget.privateState?['alive'] == false)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Mode spectateur · Vous pouvez lire les échanges du jour, sans écrire ni voter.',
          ),
        ),
      if (!widget.fullPage)
        Center(
          child: Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      const SizedBox(height: 12),
      Text(
        day
            ? 'Discussion générale'
            : pack
            ? 'Discussion de la meute'
            : 'Discussion fermée',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      Text(
        day
            ? (game?['chat_open'] == true)
                  ? 'Discussion ouverte · Le MDJ dirige le débat et le vote.'
                  : 'Discussion fermée par le MDJ · Lecture des échanges.'
            : pack
            ? 'Échanges éphémères · uniquement pendant le réveil de la meute.'
            : 'Les discussions reprendront au prochain appel autorisé.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 12),
    ];
    final composer = <Widget>[
      if (writable) ...[
        TextField(
          controller: _text,
          maxLength: 300,
          decoration: InputDecoration(
            labelText: 'Ton message',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.chat_bubble_outline),
            suffixIcon: IconButton(
              tooltip: 'Stickers',
              onPressed: _selectSticker,
              icon: const Icon(Icons.emoji_emotions_outlined),
            ),
          ),
        ),
        FilledButton(
          onPressed: () {
            if (_text.text.trim().isEmpty) return;
            widget.onSend(
              day ? 'day.chat' : 'wolves.chat',
              game!['phase_revision'] as int,
              _text.text.trim(),
            );
            _text.clear();
          },
          child: const Text('Envoyer'),
        ),
      ] else
        Text(
          widget.isHost
              ? 'Vue du MDJ : lecture des échanges autorisés.'
              : 'Tu peux lire les échanges autorisés, mais pas envoyer ici.',
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: LayoutBuilder(
        builder: (context, size) {
          if (size.maxHeight < 320) {
            return ListView(
              children: [
                ...heading,
                ...composer,
                for (var i = messages.length - 1; i >= 0; i--) messageRow(i),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ...heading,
              Expanded(
                child: messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              day
                                  ? Icons.forum_outlined
                                  : Icons.nights_stay_outlined,
                              size: 44,
                              color: const Color(0xFFE1BB80),
                            ),
                            const SizedBox(height: 16),
                            const Text('Aucun message pour le moment.'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        itemCount: messages.length,
                        itemBuilder: (context, i) =>
                            messageRow(messages.length - 1 - i),
                      ),
              ),
              ...composer,
            ],
          );
        },
      ),
    );
  }
}
