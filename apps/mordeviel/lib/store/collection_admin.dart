import 'package:flutter/material.dart';
import '../community/admin_dashboard.dart';

class CollectionAdminScreen extends StatefulWidget {
  const CollectionAdminScreen({super.key, required this.request});
  final AdminRequest request;
  @override
  State<CollectionAdminScreen> createState() => _CollectionAdminScreenState();
}

class _CollectionAdminScreenState extends State<CollectionAdminScreen> {
  Map<String, dynamic>? _data;
  bool _busy = false;
  String? _error;
  String _filter = 'intense';
  final _days = TextEditingController(text: '30');
  @override
  void dispose() {
    _days.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await widget.request('admin/collection');
      if (mounted) {
        setState(() {
          _data = data;
          _days.text = '${data['free_days_configured'] ?? 30}';
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _run(
    String path,
    Map<String, dynamic>? data, {
    String method = 'PUT',
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.request(
        'admin/collection/$path',
        method: method,
        body: data,
      );
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<Map> get _products => (_data?['products'] as List? ?? []).cast<Map>();
  Future<List<String>?> _select(
    String title,
    List<String> initial, {
    String? kind,
  }) => showDialog<List<String>>(
    context: context,
    builder: (context) {
      final selected = initial.toSet();
      return StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 450,
            height: 400,
            child: ListView(
              children: [
                for (final p in _products.where(
                  (p) =>
                      p['theme'] != 'classic' &&
                      (kind == null || p['kind'] == kind),
                ))
                  CheckboxListTile(
                    value: selected.contains(p['id']),
                    title: Text('${p['title']} · ${p['theme']}'),
                    subtitle: Text(p['kind'] as String),
                    onChanged: (v) => update(() {
                      if (v == true) {
                        selected.add(p['id'] as String);
                      } else {
                        selected.remove(p['id']);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected.toList()),
              child: const Text('Valider'),
            ),
          ],
        ),
      );
    },
  );
  Future<void> _edit(Map p) async {
    final price = TextEditingController(
      text: p['price_minor']?.toString() ?? '',
    );
    var visible = p['visible'] == 1,
        shop = p['shop'] == 1,
        collector = p['collector'] == 1;
    var currency = p['currency'] as String;
    var bonus = (p['bonus'] as List).cast<String>();
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(p['title'] as String),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Prix en unité minimale : XOF entier, centimes pour EUR/USD. Vide = aucun ajout possible. Zéro = gratuit.',
                  ),
                  TextField(
                    controller: price,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Prix publié (facultatif)',
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: currency,
                    items: [
                      for (final c in ['XOF', 'EUR', 'USD'])
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => update(() => currency = v!),
                  ),
                  SwitchListTile(
                    title: const Text('Visible'),
                    value: visible,
                    onChanged: (v) => update(() => visible = v),
                  ),
                  SwitchListTile(
                    title: const Text('Boutique'),
                    value: shop,
                    onChanged: (v) => update(() => shop = v),
                  ),
                  SwitchListTile(
                    title: const Text('Éligible au Collectionneur'),
                    value: collector,
                    onChanged: (v) => update(() => collector = v),
                  ),
                  TextButton(
                    onPressed: () async {
                      final selected = await _select(
                        'Bonus inclus (maximum 10)',
                        bonus,
                      );
                      if (selected != null && context.mounted) {
                        update(
                          () => bonus = selected
                              .where((id) => id != p['id'])
                              .take(10)
                              .toList(),
                        );
                      }
                    },
                    child: Text('${bonus.length} bonus · Modifier'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final number = int.tryParse(price.text.trim());
                if (price.text.trim().isNotEmpty &&
                    (number == null || number < 0)) {
                  return;
                }
                Navigator.pop(context, {
                  'price_minor': number,
                  'currency': currency,
                  'visible': visible,
                  'shop': shop,
                  'collector': collector,
                  'bonus': bonus,
                });
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    price.dispose();
    if (data != null) await _run('products/${p['id']}', data);
  }

  Future<void> _trial() async {
    final title = TextEditingController(text: 'Journée découverte');
    final start = TextEditingController(text: _data!['day'] as String);
    final end = TextEditingController(text: _data!['day'] as String);
    var ids = <String>[];
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Programmer un essai gratuit'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Nom'),
                  ),
                  TextField(
                    controller: start,
                    decoration: const InputDecoration(
                      labelText: 'Premier jour · AAAA-MM-JJ (UTC)',
                    ),
                  ),
                  TextField(
                    controller: end,
                    decoration: const InputDecoration(
                      labelText: 'Dernier jour inclus · AAAA-MM-JJ',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final selected = await _select(
                        'Cartes et packs en essai',
                        ids,
                      );
                      if (selected != null && context.mounted) {
                        update(() => ids = selected);
                      }
                    },
                    child: Text(
                      ids.isEmpty
                          ? 'Tous les produits · choisir une sélection'
                          : '${ids.length} produits sélectionnés',
                    ),
                  ),
                  const Text(
                    'Un essai ouvre l’accès temporairement sans attribuer la propriété.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                if (DateTime.tryParse(start.text) == null ||
                    DateTime.tryParse(end.text) == null ||
                    title.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(context, {
                  'title': title.text.trim(),
                  'starts': start.text.trim(),
                  'ends': end.text.trim(),
                  'products': ids,
                  'enabled': true,
                });
              },
              child: const Text('Programmer'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    title.dispose();
    start.dispose();
    end.dispose();
    if (data != null) await _run('trials', data, method: 'POST');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Collections & Collectionneur')),
    body: _data == null
        ? Center(
            child: _error == null
                ? const CircularProgressIndicator()
                : Text(_error!),
          )
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Restrictions de collection',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Text(
                'Le mode test verrouille les produits non acquis hors essai. Les classiques restent disponibles. Aucun paiement réel.',
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _run('settings', {
                        'free_access': _data!['free_access'] != true,
                      }),
                icon: Icon(
                  _data!['free_access'] == true
                      ? Icons.lock_outline
                      : Icons.lock_open,
                ),
                label: Text(
                  _data!['free_access'] == true
                      ? 'Activer les restrictions — test'
                      : 'Rétablir l’accès gratuit',
                ),
              ),
              if (_busy) const LinearProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                'Gratuité jusqu’au ${_data!['free_until']} · ${_data!['free_days_remaining']} jours restants (UTC)',
              ),
              TextField(
                controller: _days,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Durée gratuite à compter d’aujourd’hui (jours)',
                ),
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () {
                        final days = int.tryParse(_days.text);
                        if (days != null && days > 0 && days <= 3650) {
                          _run('settings', {
                            'free_access': _data!['free_access'],
                            'free_days': days,
                          });
                        }
                      },
                child: const Text('Appliquer cette durée'),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
              const SizedBox(height: 20),
              Text(
                'Le Collectionneur · ${_data!['day']}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'Rotation automatique quotidienne : 5 cartes, voix rare, environnement très rare. Tu peux remplacer la sélection du jour.',
              ),
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () async {
                        final selected = await _select(
                          '5 cartes + au plus 1 voix et 1 thème',
                          (_data!['daily_ids'] as List).cast<String>(),
                        );
                        if (selected != null) {
                          await _run('daily', {
                            'day': _data!['day'],
                            'products': selected,
                          });
                        }
                      },
                icon: const Icon(Icons.style),
                label: const Text('Choisir les offres du jour'),
              ),
              for (final id in _data!['daily_ids'] as List)
                ListTile(
                  dense: true,
                  title: Text(
                    _products.firstWhere((p) => p['id'] == id)['title']
                        as String,
                  ),
                  subtitle: Text(id as String),
                ),
              const Divider(),
              FilledButton.tonalIcon(
                onPressed: _busy ? null : _trial,
                icon: const Icon(Icons.event_available),
                label: const Text('Programmer un essai gratuit'),
              ),
              for (final t in _data!['trials'] as List)
                ListTile(
                  title: Text(t['title'] as String),
                  subtitle: Text(
                    '${t['starts']} → ${t['ends']} · ${(t['products'] as List).isEmpty ? 'Tous les produits' : '${(t['products'] as List).length} produits'}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Supprimer cet essai',
                    onPressed: _busy
                        ? null
                        : () =>
                              _run('trials/${t['id']}', null, method: 'DELETE'),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              const Divider(),
              Text(
                'Produits, prix et bonus',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final theme in ['intense', 'horror'])
                    ChoiceChip(
                      label: Text(theme == 'intense' ? 'Intense' : 'Horreur'),
                      selected: _filter == theme,
                      onSelected: (_) => setState(() => _filter = theme),
                    ),
                ],
              ),
              for (final p in _products.where((p) => p['theme'] == _filter))
                Card(
                  child: ListTile(
                    title: Text(p['title'] as String),
                    subtitle: Text(
                      '${p['kind']} · ${p['price_minor'] == null ? 'Prix non publié' : '${p['price_minor']} ${p['currency']} (unité minimale)'}\n${p['visible'] == 1 ? 'Visible' : 'Masqué'} · ${(p['bonus'] as List).length} bonus',
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: _busy ? null : () => _edit(p),
                  ),
                ),
            ],
          ),
  );
}
