import 'package:flutter/material.dart';
import '../services/public_content.dart';

class OfficialContentPage extends StatefulWidget {
  const OfficialContentPage({
    super.key,
    required this.faq,
    this.standalone = false,
  });
  final bool faq, standalone;
  @override
  State<OfficialContentPage> createState() => _OfficialContentPageState();
}

class _OfficialContentPageState extends State<OfficialContentPage> {
  List<Map<String, dynamic>> _items = [];
  String _search = '';
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final info = await loadPublicContent('community/info');
      if (mounted) {
        setState(
          () => _items = (info[widget.faq ? 'faq' : 'announcements'] as List)
              .map((p) => Map<String, dynamic>.from(p as Map))
              .toList(),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Impossible de charger le contenu pour le moment.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _items
        .where(
          (p) => '${p['title']} ${p['body']}'.toLowerCase().contains(
            _search.toLowerCase(),
          ),
        )
        .toList();
    final body = ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.faq ? 'Questions fréquentes' : 'Annonces officielles',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Actualiser',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (widget.faq)
          TextField(
            onChanged: (value) => setState(() => _search = value),
            decoration: const InputDecoration(
              labelText: 'Rechercher dans la FAQ',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_error != null) ...[
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Réessayer')),
        ],
        if (!_loading && _error == null && filtered.isEmpty)
          Text(
            _search.isEmpty
                ? 'Aucune publication pour le moment.'
                : 'Aucun résultat. Tu peux poser ta question au support.',
          ),
        for (final item in filtered)
          Card(
            child: widget.faq
                ? ExpansionTile(
                    title: Text(item['title'] as String),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(item['body'] as String),
                      ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Équipe Legende of Wolf · Officiel'),
                        const SizedBox(height: 8),
                        Text(
                          item['title'] as String,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        SelectableText(item['body'] as String),
                      ],
                    ),
                  ),
          ),
      ],
    );
    return widget.standalone
        ? Scaffold(
            appBar: AppBar(title: Text(widget.faq ? 'FAQ' : 'Annonces')),
            body: body,
          )
        : body;
  }
}
