import 'package:flutter/material.dart';
import 'package:local_host/local_host.dart' show ChatSticker, chatStickers;
import '../content/require_packs.dart';
import '../social/social_api.dart';
import 'chat_stickers.dart';
import 'sticker_keywords.dart';

class StickerSuggestions extends StatefulWidget {
  const StickerSuggestions({
    super.key,
    required this.controller,
    required this.onSelect,
    this.enabled = true,
    this.scope = 'chat',
  });
  final TextEditingController controller;
  final ValueChanged<ChatSticker> onSelect;
  final bool enabled;
  final Object scope;
  @override
  State<StickerSuggestions> createState() => _StickerSuggestionsState();
}

class _StickerSuggestionsState extends State<StickerSuggestions> {
  final _allowed = <String>{};
  bool _selecting = false;
  @override
  void initState() {
    super.initState();
    _loadAccess();
  }

  Future<void> _loadAccess() async {
    try {
      final data = await SocialApi.instance.request('/collection/me');
      if (!mounted) return;
      setState(() {
        _allowed.addAll(
          (data['products'] as List)
              .where((p) => p['kind'] == 'sticker' && p['accessible'] == true)
              .map((p) => p['id'] as String),
        );
      });
    } catch (_) {
      // The 17 Classic stickers remain eligible without a community session.
    }
  }

  Future<void> _select(ChatSticker sticker) async {
    if (_selecting || !widget.enabled) return;
    _selecting = true;
    final scope = widget.scope;
    try {
      final ready = await ensurePacksAvailable(context, [
        sticker.packId,
      ], reason: 'Télécharge ce pack pour envoyer le sticker proposé.');
      if (ready && mounted && widget.enabled && widget.scope == scope) {
        widget.onSelect(sticker);
      }
    } finally {
      _selecting = false;
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: widget.controller,
    builder: (context, value, _) {
      final matches = widget.enabled
          ? suggestStickers(
              value.text,
              stickers: chatStickers.where(
                (s) => s.productId == null || _allowed.contains(s.productId),
              ),
            )
          : <ChatSticker>[];
      if (matches.isEmpty) return const SizedBox.shrink();
      return Semantics(
        label: 'Stickers suggérés selon ton message',
        child: SizedBox(
          key: const ValueKey('sticker-suggestions'),
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            itemCount: matches.length,
            separatorBuilder: (_, _) => const SizedBox(width: 7),
            itemBuilder: (context, i) {
              final sticker = matches[i];
              return Tooltip(
                message: 'Envoyer ${sticker.label}',
                child: Material(
                  color: const Color(0xFF24333A),
                  borderRadius: BorderRadius.circular(11),
                  child: InkWell(
                    key: ValueKey('suggest-${sticker.id}'),
                    borderRadius: BorderRadius.circular(11),
                    onTap: () => _select(sticker),
                    child: SizedBox(
                      width: 78,
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Column(
                          children: [
                            Expanded(
                              child: IgnorePointer(
                                child: ChatStickerImage(
                                  sticker: sticker,
                                  size: 48,
                                ),
                              ),
                            ),
                            Text(
                              sticker.emotion,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFFE3C58C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  );
}
