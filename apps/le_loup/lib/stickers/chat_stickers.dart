import 'package:flutter/material.dart';
import 'package:local_host/local_host.dart'
    show ChatSticker, chatStickers, stickerFromMessage;

class ChatStickerImage extends StatelessWidget {
  const ChatStickerImage({super.key, required this.sticker, this.size = 144});
  final ChatSticker sticker;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: sticker.label,
    child: SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        sticker.asset,
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
            .ceil()
            .clamp(96, 512),
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) =>
            Center(child: Text('Sticker : ${sticker.label}')),
      ),
    ),
  );
}

class ChatMessageBody extends StatelessWidget {
  const ChatMessageBody({
    super.key,
    required this.text,
    this.selectable = false,
  });
  final String text;
  final bool selectable;
  @override
  Widget build(BuildContext context) {
    final sticker = stickerFromMessage(text);
    if (sticker != null) return ChatStickerImage(sticker: sticker);
    if (text.trim().startsWith('[[sticker:')) {
      return const Text('Sticker indisponible');
    }
    return selectable ? SelectableText(text) : Text(text);
  }
}

Future<ChatSticker?> showStickerPicker(BuildContext context) =>
    showModalBottomSheet<ChatSticker>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: const FractionallySizedBox(
          heightFactor: .78,
          child: StickerPicker(),
        ),
      ),
    );

class StickerPicker extends StatefulWidget {
  const StickerPicker({super.key});
  @override
  State<StickerPicker> createState() => _StickerPickerState();
}

class _StickerPickerState extends State<StickerPicker> {
  String _query = '';
  bool _chosen = false;
  String normalize(String value) {
    var result = value.toLowerCase();
    for (final pair in {
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'à': 'a',
      'â': 'a',
      'î': 'i',
      'ï': 'i',
      'ô': 'o',
      'ö': 'o',
      'ù': 'u',
      'û': 'u',
      'ç': 'c',
      'œ': 'oe',
    }.entries) {
      result = result.replaceAll(pair.key, pair.value);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final query = normalize(_query.trim());
    final matches = chatStickers
        .where((s) => normalize(s.label).contains(query))
        .toList();
    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Émotions du village',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Fermer les stickers',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Tous les personnages sont disponibles pour tout le monde.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Rôle ou émotion',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: matches.isEmpty
                ? const Center(
                    child: Text('Aucun sticker pour cette recherche.'),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 150,
                          childAspectRatio: .82,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: matches.length,
                    itemBuilder: (context, i) {
                      final sticker = matches[i];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          key: ValueKey('pick-${sticker.id}'),
                          onTap: () {
                            if (_chosen) return;
                            _chosen = true;
                            Navigator.pop(context, sticker);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Center(
                                    child: ChatStickerImage(
                                      sticker: sticker,
                                      size: 100,
                                    ),
                                  ),
                                ),
                                Text(
                                  sticker.emotion,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  sticker.role,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
