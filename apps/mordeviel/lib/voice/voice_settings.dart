import 'package:flutter/material.dart';
import 'package:local_host/local_host.dart';

Future<void> showVoiceSettings(BuildContext context, OnlineHost host) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _VoiceSettings(host: host),
    );

class _VoiceSettings extends StatefulWidget {
  const _VoiceSettings({required this.host});
  final OnlineHost host;
  @override
  State<_VoiceSettings> createState() => _VoiceSettingsState();
}

class _VoiceSettingsState extends State<_VoiceSettings> {
  bool _busy = false;
  String? _error;
  Future<void> _save({bool? enabled, bool? open, List<String>? muted}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final room = widget.host.snapshot;
    try {
      await widget.host.command('voice.configure', {
        'enabled': enabled ?? room['voice_enabled'] == true,
        'open': open ?? room['voice_open'] != false,
        'muted': muted ?? (room['voice_muted'] as List? ?? []),
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is StateError
              ? error.message.toString()
              : 'Le réglage vocal n’a pas pu être enregistré.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: StreamBuilder<Map<String, dynamic>>(
      stream: widget.host.updates,
      initialData: widget.host.snapshot,
      builder: (context, snapshot) {
        final room = snapshot.data ?? widget.host.snapshot;
        final muted = (room['voice_muted'] as List? ?? []).cast<String>();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'La parole au village',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Le jour, le conseil peut parler. Pendant leur appel, les loups disposent de leur canal privé. Les spectateurs restent muets.',
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Activer le vocal du salon'),
                value: room['voice_enabled'] == true,
                onChanged: _busy ? null : (v) => _save(enabled: v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Autoriser les joueurs à parler'),
                value: room['voice_open'] != false,
                onChanged: _busy ? null : (v) => _save(open: v),
              ),
              for (final player in (room['players'] as List? ?? []).where(
                (p) => p['is_bot'] != true,
              ))
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Rendre muet : ${player['nickname']}'),
                  value: muted.contains(player['id']),
                  onChanged: _busy
                      ? null
                      : (v) => _save(
                          muted: [
                            for (final id in muted)
                              if (id != player['id']) id,
                            if (v == true) player['id'] as String,
                          ],
                        ),
                ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Color(0xFFFFB7A5))),
              const SizedBox(height: 12),
              const Text(
                'Micro coupé au départ, au changement de phase et en arrière-plan. Le vocal reste facultatif.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        );
      },
    ),
  );
}
