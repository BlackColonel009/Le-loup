import 'package:flutter/material.dart';
import 'pack_store.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});
  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      await PackStore.instance.refresh();
    } catch (_) {
      /* Offline catalogue remains visible. */
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _install(String id) async {
    try {
      await PackStore.instance.install(id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              PackStore.instance.error ?? 'Téléchargement impossible.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mes téléchargements'),
      actions: [
        IconButton(
          onPressed: _refresh,
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualiser',
        ),
      ],
    ),
    body: ListenableBuilder(
      listenable: PackStore.instance,
      builder: (context, _) {
        final store = PackStore.instance;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Installe tes packs une fois, puis retrouve-les hors connexion. Les voix classiques et les extraits de test sont déjà inclus.',
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            if (store.error != null) Text(store.error!),
            if (store.packs.any((p) => p['theme'] == 'horror'))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Le thème Horreur complet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Text(
                        'Cartes, village, sentences et sons d’ambiance.',
                      ),
                      FilledButton.icon(
                        onPressed: store.progress.isNotEmpty
                            ? null
                            : () async {
                                for (final id in [
                                  'horror-cards',
                                  'horror-village',
                                  'horror-ambience',
                                ]) {
                                  if (!store.installed(id)) {
                                    try {
                                      await store.install(id);
                                    } catch (_) {
                                      break;
                                    }
                                  }
                                }
                              },
                        icon: const Icon(Icons.download),
                        label: const Text('Télécharger tout le thème'),
                      ),
                    ],
                  ),
                ),
              ),
            for (final pack in store.packs)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        pack['title'] as String,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${((pack['size'] as num) / 1048576).toStringAsFixed(1)} Mo · ${store.installed(pack['id'] as String) ? 'Installé' : 'À télécharger / mettre à jour'}',
                      ),
                      if (store.progress.containsKey(pack['id'])) ...[
                        LinearProgressIndicator(
                          value: store.progress[pack['id']],
                        ),
                        TextButton(
                          onPressed: () => store.cancel(pack['id'] as String),
                          child: const Text('Suspendre'),
                        ),
                      ] else
                        Wrap(
                          spacing: 12,
                          children: [
                            FilledButton.icon(
                              onPressed: store.installed(pack['id'] as String)
                                  ? null
                                  : () => _install(pack['id'] as String),
                              icon: const Icon(Icons.download),
                              label: const Text('Télécharger / reprendre'),
                            ),
                            TextButton(
                              onPressed: () async {
                                final yes = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text(
                                      'Supprimer ce pack du téléphone ?',
                                    ),
                                    content: const Text(
                                      'Tu pourras le télécharger à nouveau.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Annuler'),
                                      ),
                                      FilledButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Supprimer'),
                                      ),
                                    ],
                                  ),
                                );
                                if (yes == true) {
                                  await store.remove(pack['id'] as String);
                                }
                              },
                              child: const Text('Supprimer'),
                            ),
                          ],
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
