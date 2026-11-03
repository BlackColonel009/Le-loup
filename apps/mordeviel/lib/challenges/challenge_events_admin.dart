import 'package:flutter/material.dart';
import '../social/social_api.dart';

class ChallengeEventsAdmin extends StatefulWidget {
  const ChallengeEventsAdmin({super.key});
  @override
  State<ChallengeEventsAdmin> createState() => _ChallengeEventsAdminState();
}

class _ChallengeEventsAdminState extends State<ChallengeEventsAdmin> {
  List _events = [];
  bool _busy = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await SocialApi.instance.request('/challenges/admin/events');
      if (mounted) {
        setState(() {
          _events = data['events'] as List;
          _busy = false;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _busy = false;
        });
      }
    }
  }

  String date(num epoch) => DateTime.fromMillisecondsSinceEpoch(
    (epoch * 1000).round(),
  ).toLocal().toString().substring(0, 16);
  Future<void> _edit([Map? event]) async {
    final id = TextEditingController(text: event?['id'] as String? ?? '');
    final title = TextEditingController(text: event?['title'] as String? ?? '');
    var start = event == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(
            ((event['starts'] as num) * 1000).round(),
          );
    var end = event == null
        ? start.add(const Duration(days: 1))
        : DateTime.fromMillisecondsSinceEpoch(
            ((event['ends'] as num) * 1000).round(),
          );
    var enabled = event?['enabled'] != 0;
    bool saving = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) {
          Future<DateTime?> pick(DateTime initial) async {
            final day = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(2026),
              lastDate: DateTime(2099),
            );
            if (day == null || !context.mounted) return null;
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(initial),
            );
            return time == null
                ? null
                : DateTime(
                    day.year,
                    day.month,
                    day.day,
                    time.hour,
                    time.minute,
                  );
          }

          return AlertDialog(
            title: const Text('Événement officiel'),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: id,
                      enabled: event == null && !saving,
                      decoration: const InputDecoration(
                        labelText: 'Identifiant unique',
                        hintText: 'nuits-de-novembre',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: title,
                      maxLength: 100,
                      decoration: const InputDecoration(
                        labelText: 'Nom de l’événement',
                      ),
                    ),
                    ListTile(
                      title: const Text('Début'),
                      subtitle: Text(start.toString().substring(0, 16)),
                      onTap: saving
                          ? null
                          : () async {
                              final chosen = await pick(start);
                              if (chosen != null && context.mounted) {
                                update(() => start = chosen);
                              }
                            },
                    ),
                    ListTile(
                      title: const Text('Fin'),
                      subtitle: Text(end.toString().substring(0, 16)),
                      onTap: saving
                          ? null
                          : () async {
                              final chosen = await pick(end);
                              if (chosen != null && context.mounted) {
                                update(() => end = chosen);
                              }
                            },
                    ),
                    SwitchListTile(
                      title: const Text('Événement activé'),
                      value: enabled,
                      onChanged: saving
                          ? null
                          : (v) => update(() => enabled = v),
                    ),
                    const Text(
                      'Les parties humaines commencées pendant cette période comptent. Un même identifiant représente toujours le même événement.',
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(error!),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialog),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!RegExp(r'^[a-z0-9-]{3,60}$').hasMatch(id.text) ||
                            title.text.trim().length < 3 ||
                            !end.isAfter(start)) {
                          update(
                            () => error =
                                'Vérifie l’identifiant, le nom et les dates.',
                          );
                          return;
                        }
                        update(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          await SocialApi.instance.request(
                            '/challenges/admin/events/${id.text}',
                            method: 'PUT',
                            body: {
                              'title': title.text.trim(),
                              'starts': start.millisecondsSinceEpoch / 1000,
                              'ends': end.millisecondsSinceEpoch / 1000,
                              'enabled': enabled,
                            },
                          );
                          if (dialog.mounted) Navigator.pop(dialog);
                        } catch (e) {
                          if (context.mounted) {
                            update(() {
                              saving = false;
                              error = e.toString();
                            });
                          }
                        }
                      },
                child: Text(saving ? 'Enregistrement…' : 'Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
    id.dispose();
    title.dispose();
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Défis · Événements officiels')),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const Text(
          'Les défis « Nuit de fête » et « Mémoire des saisons » suivent ces événements. Les récompenses sont attribuées à la fin des parties éligibles.',
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _busy ? null : () => _edit(),
          icon: const Icon(Icons.add),
          label: const Text('Préparer un événement'),
        ),
        const SizedBox(height: 20),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) Text(_error!),
        for (final event in _events)
          Card(
            child: ListTile(
              leading: Icon(
                event['enabled'] == 1
                    ? Icons.event_available
                    : Icons.event_busy,
              ),
              title: Text(event['title'] as String),
              subtitle: Text(
                '${date(event['starts'] as num)} → ${date(event['ends'] as num)}',
              ),
              trailing: const Icon(Icons.edit),
              onTap: () => _edit(event as Map),
            ),
          ),
      ],
    ),
  );
}
