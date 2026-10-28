import 'package:flutter/material.dart';
import 'downloads_screen.dart';
import 'pack_store.dart';
import 'pack_messages.dart';

Future<bool> ensurePacksAvailable(
  BuildContext context,
  Iterable<String> ids, {
  required String reason,
  PackStore? store,
}) async {
  final packs = store ?? PackStore.instance;
  final required = ids.toSet();
  if (required.isEmpty) return true;
  try {
    await packs.initialize();
  } catch (_) {
    /* Explain in the dialog. */
  }
  final missing = required.where((id) => !packs.installed(id)).toList();
  if (missing.isEmpty) return true;
  if (!context.mounted) return false;
  final open = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      title: const Text('Packs à télécharger'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reason),
            const SizedBox(height: 12),
            for (final id in missing)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('• ${packLabel(id)}'),
              ),
            const SizedBox(height: 12),
            const Text(
              'Ces fichiers ne sont pas encore installés, sont incomplets ou nécessitent une mise à jour. Télécharge-les avec Internet ; ils resteront ensuite disponibles hors connexion.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialog, false),
          child: const Text('Plus tard'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(dialog, true),
          icon: const Icon(Icons.download),
          label: const Text('Ouvrir les téléchargements'),
        ),
      ],
    ),
  );
  if (open == true && context.mounted) {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            DownloadsScreen(requiredPackIds: missing.toSet(), store: packs),
      ),
    );
  }
  return required.every(packs.installed);
}
