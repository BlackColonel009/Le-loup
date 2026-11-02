import 'dart:async';
import 'package:flutter/material.dart';
import 'admin_dashboard.dart' show AdminRequest;
import 'admin_drafts.dart';

class PublicationDialog extends StatefulWidget {
  const PublicationDialog({
    super.key,
    required this.request,
    required this.drafts,
    this.item,
  });
  final AdminRequest request;
  final AdminDrafts drafts;
  final Map? item;
  @override
  State<PublicationDialog> createState() => _PublicationDialogState();
}

class _PublicationDialogState extends State<PublicationDialog> {
  final _title = TextEditingController(), _body = TextEditingController();
  String _kind = 'announcement';
  bool _loading = true, _busy = false;
  String? _error;
  String _status =
      'Brouillon enregistré sur cet appareil. Rien n’est publié automatiquement.';
  String get _slot => 'publication-${widget.item?['id'] ?? 'new'}';

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final draft = await widget.drafts.read(_slot);
    if (!mounted) return;
    final source = draft ?? widget.item;
    _kind = source?['kind'] as String? ?? 'announcement';
    _title.text = source?['title'] as String? ?? '';
    _body.text = source?['body'] as String? ?? '';
    _title.addListener(_saveDraft);
    _body.addListener(_saveDraft);
    setState(() {
      _loading = false;
      if (draft != null) _status = 'Brouillon restauré. Il n’est pas publié.';
    });
  }

  void _saveDraft() {
    final data = {'kind': _kind, 'title': _title.text, 'body': _body.text};
    unawaited(
      widget.drafts.save(_slot, data).then((stored) {
        if (mounted) {
          setState(
            () => _status = stored
                ? 'Brouillon enregistré sur cet appareil. Rien n’est publié automatiquement.'
                : 'Brouillon conservé pour cette session ; stockage local indisponible.',
          );
        }
      }),
    );
  }

  Future<void> _publish() async {
    if (_busy) return;
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      setState(() => _error = 'Le titre et le texte sont requis.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.request(
        widget.item == null
            ? 'admin/content'
            : 'admin/content/${widget.item!['id']}',
        method: widget.item == null ? 'POST' : 'PUT',
        body: {
          'kind': _kind,
          'title': _title.text.trim(),
          'body': _body.text.trim(),
        },
      );
      await widget.drafts.clear(_slot);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error =
              'Publication non confirmée. Ton brouillon est conservé ; vérifie la liste avant de réessayer.';
        });
      }
    }
  }

  Future<void> _discard() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Effacer ce brouillon ?'),
        content: const Text(
          'La publication déjà visible, s’il y en a une, restera inchangée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Conserver'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.drafts.clear(_slot);
    if (mounted) Navigator.pop(context, false);
  }

  @override
  void dispose() {
    _title.removeListener(_saveDraft);
    _body.removeListener(_saveDraft);
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('Publication officielle'),
      content: SizedBox(
        width: 480,
        child: _loading
            ? const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_status, key: const ValueKey('draft-status')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _kind,
                      items: const [
                        DropdownMenuItem(
                          value: 'announcement',
                          child: Text('Annonce'),
                        ),
                        DropdownMenuItem(value: 'faq', child: Text('FAQ')),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) {
                              setState(() => _kind = value ?? 'announcement');
                              _saveDraft();
                            },
                    ),
                    TextField(
                      controller: _title,
                      enabled: !_busy,
                      maxLength: 160,
                      decoration: const InputDecoration(
                        labelText: 'Titre ou question',
                      ),
                    ),
                    TextField(
                      controller: _body,
                      enabled: !_busy,
                      minLines: 3,
                      maxLines: 10,
                      maxLength: 6000,
                      decoration: const InputDecoration(
                        labelText: 'Texte ou réponse',
                      ),
                    ),
                    if (_error != null)
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _busy || _loading ? null : _discard,
          child: const Text('Effacer le brouillon'),
        ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Fermer'),
        ),
        FilledButton(
          onPressed: _busy || _loading ? null : _publish,
          child: Text(
            widget.item == null
                ? 'Publier dans le jeu'
                : 'Enregistrer dans le jeu',
          ),
        ),
      ],
    ),
  );
}
