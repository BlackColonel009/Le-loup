import 'package:flutter/material.dart';
import 'pack_store.dart';
import 'pack_messages.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({
    super.key,
    this.requiredPackIds = const {},
    this.store,
  });
  final Set<String> requiredPackIds;
  final PackStore? store;
  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  bool _loading = true;
  String? _localError;
  PackStore get _store => widget.store ?? PackStore.instance;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _localError = null;
      });
    }
    try {
      await _store.refresh();
    } catch (_) {
      _localError =
          _store.error ??
          'Impossible d’ouvrir les téléchargements. Vérifie l’espace libre et réessaie.';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<bool> _install(String id) async {
    try {
      await _store.install(id);
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _store.error ??
                  'Impossible de télécharger ce pack. Actualise la liste puis réessaie.',
            ),
          ),
        );
      }
      return false;
    }
  }

  Future<void> _installRequired() async {
    for (final id in widget.requiredPackIds) {
      if (!_store.installed(id) && !await _install(id)) break;
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
      listenable: _store,
      builder: (context, _) {
        final store = _store;
        final ordered = List<Map<String, dynamic>>.of(store.packs)
          ..sort(
            (a, b) => (widget.requiredPackIds.contains(b['id']) ? 1 : 0)
                .compareTo(widget.requiredPackIds.contains(a['id']) ? 1 : 0),
          );
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Installe tes packs une fois, puis retrouve-les hors connexion. Les voix classiques et les extraits de test sont déjà inclus.',
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            if (store.error != null || _localError != null) ...[
              Text(store.error ?? _localError!),
              TextButton.icon(
                onPressed: _loading ? null : _refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
            if (widget.requiredPackIds.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Packs nécessaires pour continuer',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      for (final id in widget.requiredPackIds)
                        Text(
                          '${store.installed(id) ? '✓' : '•'} ${packLabel(id)}',
                        ),
                      const SizedBox(height: 12),
                      if (widget.requiredPackIds.every(store.installed))
                        FilledButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.check),
                          label: const Text('Revenir au jeu'),
                        )
                      else
                        FilledButton.icon(
                          onPressed:
                              _loading ||
                                  store.progress.isNotEmpty ||
                                  widget.requiredPackIds.any(
                                    (id) =>
                                        !store.packs.any((p) => p['id'] == id),
                                  )
                              ? null
                              : _installRequired,
                          icon: const Icon(Icons.download),
                          label: const Text(
                            'Télécharger les packs nécessaires',
                          ),
                        ),
                      if (!_loading &&
                          widget.requiredPackIds.any(
                            (id) => !store.packs.any((p) => p['id'] == id),
                          ))
                        const Text(
                          'Un pack demandé n’est pas disponible dans le catalogue. Actualise la liste ; si cela persiste, contacte le support.',
                        ),
                    ],
                  ),
                ),
              ),
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
                                    if (!await _install(id)) break;
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
            for (final pack in ordered)
              Card(
                key: ValueKey('download-${pack['id']}'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        pack['title'] as String,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (widget.requiredPackIds.contains(pack['id']))
                        const Text(
                          'Nécessaire pour ton action',
                          style: TextStyle(fontWeight: FontWeight.bold),
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
