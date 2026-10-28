import 'package:flutter/material.dart';
import 'admin_dashboard.dart' show AdminRequest;

class CommunityMailSettings extends StatefulWidget {
  const CommunityMailSettings({super.key, required this.request});
  final AdminRequest request;
  @override
  State<CommunityMailSettings> createState() => _CommunityMailSettingsState();
}

class _CommunityMailSettingsState extends State<CommunityMailSettings> {
  final _days = TextEditingController(),
      _subject = TextEditingController(),
      _phrases = TextEditingController();
  bool _enabled = false, _busy = true;
  String? _error;
  Map<String, dynamic>? _data;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _days.dispose();
    _subject.dispose();
    _phrases.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await widget.request('admin/mail-schedule');
      if (!mounted) return;
      setState(() {
        _data = data;
        _enabled = data['enabled'] == true;
        _days.text = '${data['interval_days']}';
        _subject.text = data['subject'] as String;
        _phrases.text = (data['phrases'] as List).join('\n');
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Chargement impossible. Réessaie.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final days = int.tryParse(_days.text.trim());
    final phrases = _phrases.text
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (days == null ||
        days < 1 ||
        days > 90 ||
        _subject.text.trim().isEmpty ||
        phrases.isEmpty ||
        phrases.length > 30 ||
        phrases.any((p) => p.length > 2000)) {
      setState(
        () => _error =
            'Choisis 1 à 90 jours, un objet et 1 à 30 phrases (2000 caractères maximum chacune).',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.request(
        'admin/mail-schedule',
        method: 'PUT',
        body: {
          'enabled': _enabled,
          'interval_days': days,
          'subject': _subject.text.trim(),
          'phrases': phrases,
        },
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Planning enregistré.')));
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Enregistrement impossible.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Rappels de la communauté')),
    body: _busy
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (_data == null)
                FilledButton(onPressed: _load, child: const Text('Réessayer')),
              if (_data != null) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Envois automatiques'),
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                ),
                TextField(
                  controller: _days,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Fréquence en jours',
                    helperText: '7 = chaque semaine · de 1 à 90 jours',
                  ),
                ),
                TextField(
                  controller: _subject,
                  maxLength: 150,
                  decoration: const InputDecoration(labelText: 'Objet du mail'),
                ),
                TextField(
                  controller: _phrases,
                  minLines: 6,
                  maxLines: 14,
                  decoration: const InputDecoration(
                    labelText: 'Messages · une phrase par ligne',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Un message différent à chaque campagne. Seuls les comptes vérifiés, non bannis et non désinscrits reçoivent ces rappels. Changer la fréquence reprogramme le prochain envoi après ce nouveau délai.',
                ),
                const SizedBox(height: 12),
                Text(
                  'Prochain envoi : ${DateTime.fromMillisecondsSinceEpoch(((_data!['next_due'] as num) * 1000).round()).toLocal()}',
                ),
                Text(
                  'Envoyés : ${(_data!['deliveries'] as Map)['sent'] ?? 0} · Échecs : ${(_data!['deliveries'] as Map)['failed'] ?? 0}',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _save,
                  child: const Text('Enregistrer les rappels'),
                ),
              ],
            ],
          ),
  );
}
