import 'package:flutter/material.dart';
import '../stickers/chat_stickers.dart';
import 'community_mail_settings.dart';

typedef AdminRequest =
    Future<Map<String, dynamic>> Function(
      String path, {
      String method,
      Map<String, dynamic>? body,
    });

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key, required this.request});
  final AdminRequest request;
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic>? _data;
  List _tickets = [], _reports = [], _content = [];
  bool _busy = false, _local = true, _online = true;
  String? _error;
  String _search = '';
  final _maintenance = TextEditingController();
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _maintenance.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final data = await widget.request('admin/dashboard');
      final tickets = await widget.request('admin/tickets');
      final reports = await widget.request('admin/reports');
      final info = await widget.request('info');
      if (!mounted) return;
      setState(() {
        _data = data;
        _tickets = tickets['tickets'] as List;
        _reports = reports['reports'] as List;
        _content = [
          ...(info['announcements'] as List),
          ...(info['faq'] as List),
        ];
        final status = data['maintenance'] as Map;
        _local = status['local_enabled'] == true;
        _online = status['online_enabled'] == true;
        _maintenance.text = status['message'] as String;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Accès au dashboard impossible. Vérifie ta connexion et tes droits administrateur.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) await _load();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message
              : 'Action impossible. Réessaie.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmer'),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _offer([Map? offer]) async {
    final id = TextEditingController(text: offer?['id'] as String? ?? '');
    final title = TextEditingController(text: offer?['title'] as String? ?? '');
    final category = TextEditingController(
      text: offer?['category'] as String? ?? 'Thèmes complets',
    );
    final description = TextEditingController(
      text: offer?['description'] as String? ?? '',
    );
    var currency = offer?['currency'] as String? ?? 'EUR';
    final price = TextEditingController(
      text:
          ((offer?['price_minor'] as num? ?? 0) / (currency == 'XOF' ? 1 : 100))
              .toStringAsFixed(currency == 'XOF' ? 0 : 2),
    );
    var visible = offer?['visible'] != 0, onSale = offer?['on_sale'] == 1;
    String? error;
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(offer == null ? 'Nouvelle offre' : 'Modifier l’offre'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: id,
                    enabled: offer == null,
                    decoration: const InputDecoration(
                      labelText: 'Identifiant (lettres minuscules)',
                    ),
                  ),
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Nom'),
                  ),
                  TextField(
                    controller: category,
                    decoration: const InputDecoration(labelText: 'Rubrique'),
                  ),
                  TextField(
                    controller: description,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: currency,
                    decoration: const InputDecoration(labelText: 'Devise'),
                    items: [
                      for (final c in ['EUR', 'USD', 'XOF'])
                        DropdownMenuItem(value: c, child: Text(c)),
                    ],
                    onChanged: (v) => update(() => currency = v ?? 'EUR'),
                  ),
                  TextField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Prix prévu'),
                  ),
                  SwitchListTile(
                    title: const Text('Visible dans la boutique'),
                    value: visible,
                    onChanged: (v) => update(() => visible = v),
                  ),
                  SwitchListTile(
                    title: const Text('Afficher l’offre et son prix'),
                    subtitle: const Text('Les paiements restent désactivés.'),
                    value: onSale,
                    onChanged: (v) => update(() => onSale = v),
                  ),
                  if (error != null) Text(error!),
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
                final parsed = double.tryParse(price.text.replaceAll(',', '.'));
                if (!RegExp(r'^[a-z0-9_-]{1,40}$').hasMatch(id.text.trim()) ||
                    title.text.trim().isEmpty ||
                    category.text.trim().isEmpty ||
                    description.text.trim().isEmpty ||
                    parsed == null ||
                    !parsed.isFinite ||
                    parsed < 0) {
                  update(() => error = 'Vérifie les champs et le prix.');
                  return;
                }
                Navigator.pop(context, {
                  'id': id.text.trim(),
                  'title': title.text.trim(),
                  'category': category.text.trim(),
                  'description': description.text.trim(),
                  'price_minor': (parsed * (currency == 'XOF' ? 1 : 100))
                      .round(),
                  'currency': currency,
                  'visible': visible,
                  'on_sale': onSale,
                });
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    for (final c in [id, title, category, description, price]) {
      c.dispose();
    }
    if (value != null && mounted) {
      await _run(
        () => widget
            .request('admin/offers/${value['id']}', method: 'PUT', body: value)
            .then((_) {}),
      );
    }
  }

  Future<void> _publication([Map? item]) async {
    final title = TextEditingController(text: item?['title'] as String? ?? '');
    final body = TextEditingController(text: item?['body'] as String? ?? '');
    var kind = item?['kind'] as String? ?? 'announcement';
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Publication officielle'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: kind,
                    items: const [
                      DropdownMenuItem(
                        value: 'announcement',
                        child: Text('Annonce'),
                      ),
                      DropdownMenuItem(value: 'faq', child: Text('FAQ')),
                    ],
                    onChanged: (v) => update(() => kind = v ?? 'announcement'),
                  ),
                  TextField(
                    controller: title,
                    maxLength: 160,
                    decoration: const InputDecoration(
                      labelText: 'Titre ou question',
                    ),
                  ),
                  TextField(
                    controller: body,
                    minLines: 3,
                    maxLines: 10,
                    maxLength: 6000,
                    decoration: const InputDecoration(
                      labelText: 'Texte ou réponse',
                    ),
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
                if (title.text.trim().isNotEmpty &&
                    body.text.trim().isNotEmpty) {
                  Navigator.pop(context, {
                    'kind': kind,
                    'title': title.text.trim(),
                    'body': body.text.trim(),
                  });
                }
              },
              child: const Text('Publier'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    title.dispose();
    body.dispose();
    if (data != null && mounted) {
      await _run(
        () => widget
            .request(
              item == null ? 'admin/content' : 'admin/content/${item['id']}',
              method: item == null ? 'POST' : 'PUT',
              body: data,
            )
            .then((_) {}),
      );
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 5,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Administration certifiée'),
        actions: [
          IconButton(
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
          ),
        ],
        bottom: const TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Contrôler'),
            Tab(text: 'Boutique'),
            Tab(text: 'Comptes'),
            Tab(text: 'Support'),
            Tab(text: 'Publications'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
          Expanded(
            child: _data == null
                ? const Center(
                    child: Text('Vérification des droits administrateur…'),
                  )
                : AbsorbPointer(
                    absorbing: _busy,
                    child: TabBarView(
                      children: [
                        ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            const Text(
                              'Contrôler l’accès au jeu',
                              style: TextStyle(fontSize: 22),
                            ),
                            SwitchListTile(
                              title: const Text('Jeu en ligne disponible'),
                              value: _online,
                              onChanged: (v) => setState(() => _online = v),
                            ),
                            SwitchListTile(
                              title: const Text('Jeu local disponible'),
                              value: _local,
                              onChanged: (v) => setState(() => _local = v),
                            ),
                            const Text(
                              'Décoche un mode pour sa maintenance. Les parties déjà lancées ne sont pas interrompues. Hors connexion, le mode local utilise le dernier état reçu.',
                            ),
                            ListTile(
                              leading: const Icon(
                                Icons.mark_email_unread_outlined,
                              ),
                              title: const Text('Rappels par email'),
                              subtitle: const Text(
                                'Fréquence, messages et activation',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => CommunityMailSettings(
                                    request: widget.request,
                                  ),
                                ),
                              ),
                            ),
                            TextField(
                              controller: _maintenance,
                              maxLength: 240,
                              decoration: const InputDecoration(
                                labelText: 'Message de maintenance',
                              ),
                            ),
                            FilledButton(
                              onPressed: () async {
                                if (await _confirm(
                                      'Appliquer ces contrôles à tous les joueurs ?',
                                    ) &&
                                    mounted) {
                                  await _run(
                                    () => widget
                                        .request(
                                          'admin/maintenance',
                                          method: 'PUT',
                                          body: {
                                            'local_enabled': _local,
                                            'online_enabled': _online,
                                            'message': _maintenance.text.trim(),
                                          },
                                        )
                                        .then((_) {}),
                                  );
                                }
                              },
                              child: const Text('Appliquer les contrôles'),
                            ),
                          ],
                        ),
                        ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            const Text(
                              'Offres et prix préparatoires · Paiements indisponibles',
                            ),
                            FilledButton.icon(
                              onPressed: () => _offer(),
                              icon: const Icon(Icons.add),
                              label: const Text('Créer une offre'),
                            ),
                            for (final p in _data!['offers'] as List)
                              Card(
                                child: ListTile(
                                  title: Text(p['title'] as String),
                                  subtitle: Text(
                                    '${((p['price_minor'] as num) / (p['currency'] == 'XOF' ? 1 : 100)).toStringAsFixed(p['currency'] == 'XOF' ? 0 : 2)} ${p['currency']} · ${p['visible'] == 1 ? 'Visible' : 'Masquée'}',
                                  ),
                                  trailing: const Icon(Icons.edit),
                                  onTap: () => _offer(p as Map),
                                ),
                              ),
                          ],
                        ),
                        ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            TextField(
                              onChanged: (v) => setState(() => _search = v),
                              decoration: const InputDecoration(
                                labelText: 'Rechercher un compte',
                              ),
                            ),
                            for (final u in (_data!['users'] as List).where(
                              (u) => (u['nickname'] as String)
                                  .toLowerCase()
                                  .contains(_search.toLowerCase()),
                            ))
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        u['nickname'] as String,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        u['role'] == 'admin'
                                            ? 'Administrateur certifié'
                                            : u['banned'] == 1
                                            ? 'Compte banni'
                                            : (u['muted_until'] as num) >
                                                  DateTime.now()
                                                          .millisecondsSinceEpoch /
                                                      1000
                                            ? 'Chat restreint'
                                            : 'Compte actif',
                                      ),
                                      if (u['role'] != 'admin')
                                        Wrap(
                                          spacing: 8,
                                          children: [
                                            TextButton(
                                              onPressed: () async {
                                                final action = u['banned'] == 1
                                                    ? 'unban'
                                                    : 'ban';
                                                if (await _confirm(
                                                      '${action == 'ban' ? 'Bannir' : 'Débannir'} ${u['nickname']} de la communauté ?',
                                                    ) &&
                                                    mounted) {
                                                  await _run(
                                                    () => widget
                                                        .request(
                                                          'admin/users/${u['id']}',
                                                          method: 'POST',
                                                          body: {
                                                            'action': action,
                                                          },
                                                        )
                                                        .then((_) {}),
                                                  );
                                                }
                                              },
                                              child: Text(
                                                u['banned'] == 1
                                                    ? 'Débannir'
                                                    : 'Bannir',
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () => _run(
                                                () => widget
                                                    .request(
                                                      'admin/users/${u['id']}',
                                                      method: 'POST',
                                                      body: {
                                                        'action': 'unmute',
                                                      },
                                                    )
                                                    .then((_) {}),
                                              ),
                                              child: const Text(
                                                'Lever la restriction du chat',
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            const Text('Demandes privées et signalements'),
                            for (final t in _tickets)
                              Card(
                                child: ListTile(
                                  title: Text(t['subject'] as String),
                                  subtitle: Text(
                                    '${t['nickname']} · ${t['status']}',
                                  ),
                                  trailing: const Icon(Icons.reply),
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => _AdminTicket(
                                          ticket: Map<String, dynamic>.from(
                                            t as Map,
                                          ),
                                          request: widget.request,
                                        ),
                                      ),
                                    );
                                    if (mounted) await _load();
                                  },
                                ),
                              ),
                            const Divider(),
                            for (final r in _reports)
                              Card(
                                child: ListTile(
                                  title: ChatMessageBody(
                                    text: r['text'] as String,
                                  ),
                                  subtitle: Text(
                                    '${r['reports']} signalement(s)',
                                  ),
                                  trailing: IconButton(
                                    tooltip: 'Masquer ce message',
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _run(
                                      () => widget
                                          .request(
                                            'admin/messages/${r['message_id']}',
                                            method: 'DELETE',
                                          )
                                          .then((_) {}),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            FilledButton.icon(
                              onPressed: () => _publication(),
                              icon: const Icon(Icons.add),
                              label: const Text('Publier une annonce ou FAQ'),
                            ),
                            for (final item in _content)
                              Card(
                                child: ListTile(
                                  title: Text(item['title'] as String),
                                  subtitle: Text(
                                    item['kind'] == 'faq' ? 'FAQ' : 'Annonce',
                                  ),
                                  onTap: () => _publication(item as Map),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    tooltip: 'Masquer la publication',
                                    onPressed: () async {
                                      if (await _confirm(
                                            'Masquer cette publication ?',
                                          ) &&
                                          mounted) {
                                        await _run(
                                          () => widget
                                              .request(
                                                'admin/content/${item['id']}',
                                                method: 'DELETE',
                                              )
                                              .then((_) {}),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}

class _AdminTicket extends StatefulWidget {
  const _AdminTicket({required this.ticket, required this.request});
  final Map<String, dynamic> ticket;
  final AdminRequest request;
  @override
  State<_AdminTicket> createState() => _AdminTicketState();
}

class _AdminTicketState extends State<_AdminTicket> {
  final _text = TextEditingController();
  List _messages = [];
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load({bool send = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (send) {
        if (_text.text.trim().isEmpty) return;
        await widget.request(
          'admin/tickets/${widget.ticket['id']}/reply',
          method: 'POST',
          body: {'text': _text.text.trim()},
        );
        _text.clear();
      }
      final data = await widget.request('admin/tickets/${widget.ticket['id']}');
      if (mounted) {
        setState(() {
          _messages = data['messages'] as List;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Chargement ou envoi impossible.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.ticket['subject'] as String)),
    body: Column(
      children: [
        if (_error != null) Text(_error!),
        Expanded(
          child: ListView(
            children: [
              for (final m in _messages)
                ListTile(
                  title: Text(
                    m['author'] == 'support'
                        ? 'Support'
                        : widget.ticket['nickname'] as String,
                  ),
                  subtitle: SelectableText(m['text'] as String),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    maxLength: 2000,
                    minLines: 1,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Réponse officielle du support',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : () => _load(send: true),
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
