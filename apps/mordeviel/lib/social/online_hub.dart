import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../community/community_screen.dart';
import 'social_api.dart';
import 'social_screens.dart';
import 'online_navigation.dart';

class OnlineHubScreen extends StatefulWidget {
  const OnlineHubScreen({super.key});
  @override
  State<OnlineHubScreen> createState() => _OnlineHubScreenState();
}

class _OnlineHubScreenState extends State<OnlineHubScreen> {
  List _rooms = [];
  bool _busy = true, _signed = false;
  String? _error;
  String _filter = 'all';
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_busy &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _busy = true);
    try {
      final data = await SocialApi.instance.request('/social/rooms');
      if (mounted) {
        setState(() {
          _rooms = data['rooms'] as List;
          _signed = true;
          _error = null;
        });
      }
    } on SocialError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _signed = e.status != 401 && e.status != 403;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final name = TextEditingController(text: 'Une nuit entre compagnons');
    var public = true, theme = 'classic';
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Ouvrir les portes du village'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  maxLength: 60,
                  decoration: const InputDecoration(labelText: 'Nom du salon'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: theme,
                  decoration: const InputDecoration(labelText: 'Thématique'),
                  items: [
                    for (final id in ['classic', 'intense', 'horror', 'mixed'])
                      DropdownMenuItem(value: id, child: Text(themeName(id))),
                  ],
                  onChanged: (v) => update(() => theme = v ?? 'classic'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Salon public'),
                  subtitle: Text(
                    public
                        ? 'Visible dans la liste des salons.'
                        : 'Accessible par code ou invitation.',
                  ),
                  value: public,
                  onChanged: (v) => update(() => public = v),
                ),
                const Text(
                  'Les cartes peuvent avoir des variantes de pouvoirs. Le Codex présente la composition et les règles avant le lancement.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, {
                'title': name.text.trim().isEmpty
                    ? 'Le village de la nuit'
                    : name.text.trim(),
                'theme': theme,
                'public': public,
              }),
              child: const Text('Créer le salon'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    name.dispose();
    if (selected == null || !mounted) return;
    await openOnlineLobby(
      context,
      publicRoom: selected['public'] as bool,
      title: selected['title'] as String,
      theme: selected['theme'] as String,
    );
    await _load();
  }

  Future<void> _joinCode() async {
    final code = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Le mot de passe du village'),
        content: TextField(
          controller: code,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: 'Code du salon · 6 chiffres',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (code.text.length == 6) Navigator.pop(dialog, code.text);
            },
            child: const Text('Rejoindre'),
          ),
        ],
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    code.dispose();
    if (value != null && mounted) {
      await openOnlineLobby(context, code: value);
      await _load();
    }
  }

  Widget _room(Map r) {
    final theme = r['theme'], joinable = r['joinable'] == true;
    final color = switch (theme) {
      'horror' => const Color(0xFFBA8CCF),
      'intense' => const Color(0xFFE8BE70),
      'mixed' => const Color(0xFF83C7C0),
      _ => const Color(0xFFD6C19C),
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withValues(alpha: .30)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    theme == 'horror'
                        ? Icons.castle_outlined
                        : theme == 'mixed'
                        ? Icons.style_outlined
                        : Icons.night_shelter_outlined,
                    color: color,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r['title'] as String,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Animé par ${r['host']}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(
                  label: Text(themeName(theme)),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  avatar: const Icon(Icons.people_outline, size: 16),
                  label: Text('${r['players']}/${r['capacity']}'),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(
                    r['phase'] != 'lobby'
                        ? 'Partie commencée'
                        : joinable
                        ? 'Préparation · Ouvert'
                        : 'Complet ou verrouillé',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (theme == 'mixed')
              Text(
                'Environnement ${themeName(r['environment'])} · Cartes de plusieurs collections',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: joinable
                    ? () async {
                        await openOnlineLobby(
                          context,
                          code: r['code'] as String,
                        );
                        await _load();
                      }
                    : null,
                icon: const Icon(Icons.login),
                label: Text(joinable ? 'Rejoindre' : 'La nuit a déjà commencé'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = _rooms
        .where((r) => _filter == 'all' || r['theme'] == _filter)
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Les villages en ligne'),
        actions: const [SocialActionBar()],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFF28303C), Color(0xFF14231F)],
                ),
                border: Border.all(color: const Color(0xFF766447)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.dark_mode_outlined,
                    color: Color(0xFFE1BA78),
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Une place autour du feu',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Rejoins un village, retrouve tes amis ou ouvre ton propre salon. La prochaine histoire commence ici.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_error!),
              ),
            if (!_signed && !_busy)
              FilledButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const CommunityScreen(),
                    ),
                  );
                  await _load();
                },
                icon: const Icon(Icons.account_circle_outlined),
                label: const Text('Me connecter pour jouer en ligne'),
              ),
            if (_signed) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final id in [
                    'all',
                    'classic',
                    'intense',
                    'horror',
                    'mixed',
                  ])
                    ChoiceChip(
                      label: Text(id == 'all' ? 'Tous' : themeName(id)),
                      selected: _filter == id,
                      onSelected: (_) => setState(() => _filter = id),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Salons publics · ${shown.length}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: _load,
                    tooltip: 'Actualiser',
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Column(
                    children: [
                      Icon(
                        Icons.cottage_outlined,
                        size: 60,
                        color: Color(0xFFE1BA78),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Les villages attendent leur première lumière.',
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Crée un salon ou rejoins tes amis avec leur code.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              for (final r in shown) _room(r as Map),
            ],
          ],
        ),
      ),
      bottomNavigationBar: _signed
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked =
                        constraints.maxWidth < 350 ||
                        MediaQuery.textScalerOf(context).scale(14) > 18;
                    final width = stacked
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: width,
                          child: OutlinedButton.icon(
                            onPressed: _busy ? null : _joinCode,
                            icon: const Icon(Icons.key),
                            label: const Text('Avec un code'),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _create,
                            icon: const Icon(Icons.add),
                            label: const Text('Créer un salon'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            )
          : null,
    );
  }
}
