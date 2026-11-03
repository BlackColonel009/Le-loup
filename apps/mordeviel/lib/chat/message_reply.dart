import 'package:flutter/material.dart';
import 'package:local_host/local_host.dart' show stickerFromMessage;

extension ReplyMessageGesture on Widget {
  Widget replyable(VoidCallback? onReply) =>
      GestureDetector(onLongPress: onReply, child: this);
}

/// La même citation compacte dans la saisie et sur la réponse publiée.
class MessageReply extends StatelessWidget {
  const MessageReply({super.key, required this.reply, this.onCancel});
  final Map reply;
  final VoidCallback? onCancel;
  @override
  Widget build(BuildContext context) {
    final unavailable = reply['unavailable'] == true;
    final text = reply['text'] as String? ?? '';
    final sticker = stickerFromMessage(text);
    return Container(
      key: ValueKey(onCancel == null ? 'message-quotation' : 'reply-composer'),
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(10, 7, 3, 7),
      constraints: const BoxConstraints(maxWidth: 520),
      decoration: BoxDecoration(
        color: const Color(0x1FD6B16D),
        border: const Border(
          left: BorderSide(color: Color(0xFFD6B16D), width: 3),
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unavailable
                      ? 'Message indisponible'
                      : '${onCancel != null ? 'Réponse à ' : ''}${reply['sender'] ?? 'Joueur'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE3C58C),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!unavailable)
                  Text(
                    sticker == null ? text : '🎭 ${sticker.label}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFC5CDC8),
                    ),
                  ),
              ],
            ),
          ),
          if (onCancel != null)
            IconButton(
              tooltip: 'Annuler la réponse',
              onPressed: onCancel,
              icon: const Icon(Icons.close, size: 18),
            )
          else
            const SizedBox(width: 7),
        ],
      ),
    );
  }
}
