import 'dart:async';
import 'package:flutter/material.dart';
import '../stickers/chat_stickers.dart';
import 'social_api.dart';
import 'package:local_host/local_host.dart' show stickerMessage;

class PrivateChatScreen extends StatefulWidget {
  const PrivateChatScreen({
    super.key,
    required this.friendId,
    required this.nickname,
  });
  final int friendId;
  final String nickname;
  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  Timer? _poll;
  List _messages = [];
  int? _viewer;
  num? _reset;
  String? _error;
  bool _sending = false, _loading = false;
  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _load();
      }
    });
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    try {
      final data = await SocialApi.instance.request(
        '/social/chats/${widget.friendId}',
      );
      if (mounted) {
        setState(() {
          _messages = data['messages'] as List;
          _viewer = data['viewer_id'] as int;
          _reset = data['reset_at'] as num?;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      _loading = false;
    }
  }

  Future<void> _send([String? sticker]) async {
    if (_sending || (sticker ?? _text.text).trim().isEmpty) return;
    final text = (sticker ?? _text.text).trim();
    setState(() => _sending = true);
    try {
      await SocialApi.instance.request(
        '/social/chats/${widget.friendId}',
        method: 'POST',
        body: {'text': text},
      );
      if (sticker == null && _text.text.trim() == text) _text.clear();
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = _reset == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            (_reset! * 1000).toInt(),
          ).difference(DateTime.now());
    final expiry = left == null
        ? 'La conversation s’efface 24 h après le premier message.'
        : 'Effacement automatique dans ${left.inHours.clamp(0, 24)} h ${left.inMinutes.remainder(60).clamp(0, 59)} min.';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nickname),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(expiry, style: Theme.of(context).textTheme.bodySmall),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(_error!),
                ),
              Expanded(
                child: _messages.isEmpty
                    ? const Center(
                        child: Text('Votre discussion privée commence ici.'),
                      )
                    : ListView.builder(
                        reverse: true,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message =
                              _messages[_messages.length - 1 - index] as Map;
                          final mine = message['sender_id'] == _viewer;
                          return Align(
                            alignment: mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              padding: const EdgeInsets.all(12),
                              constraints: const BoxConstraints(maxWidth: 360),
                              decoration: BoxDecoration(
                                color: mine
                                    ? const Color(0xFF384536)
                                    : const Color(0xFF23303A),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ChatMessageBody(
                                text: message['text'] as String,
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('private-chat-input'),
                controller: _text,
                focusNode: _focus,
                maxLength: 300,
                decoration: InputDecoration(
                  labelText: 'Ton message privé',
                  border: const OutlineInputBorder(),
                  prefixIcon: IconButton(
                    tooltip: 'Stickers',
                    icon: const Icon(Icons.emoji_emotions_outlined),
                    onPressed: _sending
                        ? null
                        : () async {
                            _focus.unfocus();
                            final selected = await showStickerPicker(context);
                            if (selected != null && mounted) {
                              await _send(stickerMessage(selected));
                            }
                          },
                  ),
                  suffixIcon: IconButton(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                    tooltip: 'Envoyer',
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
