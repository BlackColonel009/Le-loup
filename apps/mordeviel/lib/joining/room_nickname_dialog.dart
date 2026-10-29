import 'package:flutter/material.dart';

/// A room alias is never saved to the community account or reused automatically.
Future<String?> chooseRoomNickname(BuildContext context) async {
  final controller = TextEditingController();
  final form = GlobalKey<FormState>();
  final result = await showDialog<String>(
    context: context,
    builder: (dialog) {
      void submit() {
        if (form.currentState!.validate()) {
          Navigator.pop(dialog, controller.text.trim());
        }
      }

      return AlertDialog(
        title: const Text('Qui seras-tu dans ce village ?'),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choisis un pseudo pour ce salon. Ton pseudo de compte reste inchangé ; tu pourras choisir un autre nom à ta prochaine entrée.',
                ),
                const SizedBox(height: 18),
                TextFormField(
                  key: const ValueKey('room-nickname'),
                  controller: controller,
                  autofocus: true,
                  maxLength: 24,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Pseudo de partie',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      value == null ||
                          value.trim().isEmpty ||
                          value.trim().length > 24
                      ? 'Choisis un pseudo de 1 à 24 caractères.'
                      : null,
                  onFieldSubmitted: (_) => submit(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: submit,
            child: const Text('Entrer dans le village'),
          ),
        ],
      );
    },
  );
  // Wait for the dialog exit animation before disposing the editing controller.
  await Future<void>.delayed(const Duration(milliseconds: 250));
  controller.dispose();
  return result;
}
