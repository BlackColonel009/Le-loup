import 'package:flutter/material.dart';
import '../services/public_content.dart';
import 'collection_screen.dart';

const shopNotice =
    'Profitez de l’application totalement disponible pour le moment.';
const _previewProducts = [
  {
    'id': 'intense',
    'category': 'Thèmes complets',
    'title': 'Intense Premium',
    'description':
        'Village enneigé, cartes dorées, maisons et animations du pack.',
  },
  {
    'id': 'horror',
    'category': 'Thèmes complets',
    'title': 'Horreur',
    'description': 'Une collection sombre et terrifiante en préparation.',
  },
  {
    'id': 'cards',
    'category': 'Apparences de cartes',
    'title': 'Collections de cartes',
    'description':
        'Illustrations, bordures et variantes de pouvoirs présentées dans le Codex.',
  },
  {
    'id': 'voices',
    'category': 'Voix OFF',
    'title': 'Narrateurs et narratrices',
    'description': 'De nouvelles interprétations pour tes parties.',
  },
  {
    'id': 'animations',
    'category': 'Animations',
    'title': 'Effets et cérémonies',
    'description': 'Protections et mises en scène du village.',
  },
  {
    'id': 'ghosts',
    'category': 'Cosmétiques personnels',
    'title': 'Fantômes et ornements',
    'description': 'Personnalise ton apparence dans le village.',
  },
];

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});
  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  List<Map<String, dynamic>> _products = _previewProducts;
  bool _loading = true;
  String? _status;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final catalog = await loadPublicContent('shop/catalog');
      if (mounted) {
        setState(
          () => _products = (catalog['products'] as List)
              .map((p) => Map<String, dynamic>.from(p as Map))
              .toList(),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _status =
              'Aperçu de la boutique. Le catalogue sera actualisé à la prochaine connexion.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _icon(String category) => switch (category) {
    'Thèmes complets' => Icons.landscape_outlined,
    'Apparences de cartes' => Icons.style_outlined,
    'Voix OFF' => Icons.record_voice_over_outlined,
    'Animations' => Icons.auto_awesome,
    _ => Icons.face_retouching_natural,
  };
  void _unavailable() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Non disponible'),
      content: const Text(
        'Achat à venir.\n\nProfitez de l’application totalement disponible pour le moment.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Compris'),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Boutique')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.collections_bookmark_outlined),
            title: const Text('Ma collection'),
            subtitle: const Text(
              'Cartes acquises, essais et cartes à découvrir',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const CollectionScreen()),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.auto_awesome),
            title: const Text('Le Collectionneur'),
            subtitle: const Text(
              'Cinq cartes chaque jour et des trouvailles rares',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const CollectionScreen(initialTab: 1),
              ),
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.storefront_outlined, size: 40),
                const SizedBox(height: 12),
                Text(
                  'Le comptoir du village',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(shopNotice),
                const SizedBox(height: 8),
                const Text(
                  'Les achats seront ouverts plus tard. Les variantes de pouvoirs de chaque carte sont présentées dans le Codex.',
                ),
              ],
            ),
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_status != null)
          Padding(padding: const EdgeInsets.all(12), child: Text(_status!)),
        for (final category
            in _products.map((p) => p['category'] as String).toSet()) ...[
          const SizedBox(height: 20),
          Text(category, style: Theme.of(context).textTheme.titleLarge),
          for (final product in _products.where(
            (p) => p['category'] == category,
          ))
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_icon(category)),
                    const SizedBox(height: 8),
                    Text(
                      product['title'] as String,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(product['description'] as String),
                    if (product['on_sale'] == 1 &&
                        product['price_minor'] is num)
                      Text(
                        'Prix prévu : ${((product['price_minor'] as num) / (product['currency'] == 'XOF' ? 1 : 100)).toStringAsFixed(product['currency'] == 'XOF' ? 0 : 2)} ${product['currency']}',
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _unavailable,
                      icon: const Icon(Icons.shopping_bag_outlined),
                      label: const Text('Achat à venir'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    ),
  );
}
