import 'package:flutter/material.dart';
import '../content/content_image.dart';
import '../content/require_packs.dart';
import '../social/social_api.dart';
import '../store/collection_screen.dart';
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
      child: ContentImage(
        sticker.asset,
        autoDownload: true,
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
            .ceil()
            .clamp(96, 512),
        fit: BoxFit.contain,
        excludeFromSemantics: true,
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

Future<ChatSticker?> showStickerPicker(BuildContext context) async {
  return showModalBottomSheet<ChatSticker>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: const FractionallySizedBox(
        heightFactor: .78,
        child: StickerPicker(),
      ),
    ),
  );
}

class StickerPicker extends StatefulWidget {
  const StickerPicker({super.key});
  @override
  State<StickerPicker> createState() => _StickerPickerState();
}

class _StickerPickerState extends State<StickerPicker> {
  String _query = '';
  bool _chosen = false;
  bool _checking = true;
  String _pack = 'classic';
  final _allowed = <String>{};
  @override
  void initState() {
    super.initState();
    _loadAccess();
  }

  Future<void> _loadAccess() async {
    try {
      final data = await SocialApi.instance.request('/collection/me');
      if (!mounted) return;
      _allowed.clear();
      _allowed.addAll(
        (data['products'] as List)
            .where((p) => p['kind'] == 'sticker' && p['accessible'] == true)
            .map((p) => p['id'] as String),
      );
    } catch (_) {
      // Sans session ou réseau, les nouveaux accessoires restent verrouillés.
    }
    if (mounted) setState(() => _checking = false);
  }

  bool _locked(ChatSticker sticker) =>
      sticker.productId != null && !_allowed.contains(sticker.productId);
  Future<void> _pick(ChatSticker sticker) async {
    if (_chosen) return;
    if (_locked(sticker)) {
      await showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('Sticker à débloquer'),
          content: const Text(
            'Consulte les récompenses du carnet des défis dans ton profil, ou les offres de la boutique et du Collectionneur. Télécharger les images ne déverrouille pas ce sticker.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Fermer'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(dialog);
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        const CollectionScreen(initialTheme: 'extras'),
                  ),
                );
                if (mounted) await _loadAccess();
              },
              child: const Text('Voir les accessoires'),
            ),
          ],
        ),
      );
      return;
    }
    _chosen = true;
    if (await ensurePacksAvailable(context, [
          sticker.packId,
        ], reason: 'Installe ce pack pour envoyer ses stickers.') &&
        mounted) {
      Navigator.pop(context, sticker);
    } else {
      _chosen = false;
    }
  }

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
        .where((s) => s.pack == _pack && normalize(s.label).contains(query))
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
                    _pack == 'classic'
                        ? 'Émotions du village'
                        : 'Curiosités à collectionner',
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
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _pack == 'classic'
                  ? 'Les stickers classiques sont disponibles pour tout le monde.'
                  : 'Récompenses de défis · Boutique · Collectionneur${_checking ? ' · Actualisation…' : ''}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Classiques'),
                  selected: _pack == 'classic',
                  onSelected: (_) => setState(() => _pack = 'classic'),
                ),
                ChoiceChip(
                  label: const Text('À collectionner'),
                  selected: _pack == 'rewards',
                  onSelected: (_) => setState(() => _pack = 'rewards'),
                ),
              ],
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
                          onTap: () => _pick(sticker),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Center(
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Opacity(
                                          opacity: _locked(sticker) ? .4 : 1,
                                          child: IgnorePointer(
                                            child: ChatStickerImage(
                                              sticker: sticker,
                                              size: 100,
                                            ),
                                          ),
                                        ),
                                        if (_locked(sticker))
                                          const Icon(
                                            Icons.lock,
                                            color: Color(0xFFE3C58C),
                                            size: 30,
                                          ),
                                      ],
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
