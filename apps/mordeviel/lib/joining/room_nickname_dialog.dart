import 'package:flutter/material.dart';

/// A room alias is never saved to the community account or reused automatically.
class RoomIdentity {
  const RoomIdentity(this.nickname, this.appearance);
  final String nickname;
  final String? appearance;
}

Future<String?> chooseRoomNickname(BuildContext context) async =>
    (await chooseRoomIdentity(context))?.nickname;

Future<RoomIdentity?> chooseRoomIdentity(
  BuildContext context, {
  bool asHost = false,
}) async {
  final controller = TextEditingController();
  String? appearance;
  final form = GlobalKey<FormState>();
  final result = await showDialog<RoomIdentity>(
    context: context,
    builder: (dialog) {
      void submit() {
        if (form.currentState!.validate()) {
          Navigator.pop(
            dialog,
            RoomIdentity(controller.text.trim(), appearance),
          );
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
                  textInputAction: TextInputAction.next,
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
                if (!asHost) ...[
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('room-appearance'),
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Votre carte de village',
                      border: OutlineInputBorder(),
                    ),
                    hint: const Text('Villageois ou Villageoise ?'),
                    items: const [
                      DropdownMenuItem(
                        value: 'male',
                        child: Text('Masculin · Villageois'),
                      ),
                      DropdownMenuItem(
                        value: 'female',
                        child: Text('Féminin · Villageoise'),
                      ),
                    ],
                    validator: (value) => value == null
                        ? 'Choisis Villageois ou Villageoise.'
                        : null,
                    onChanged: (value) => appearance = value,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ce choix détermine votre carte de Simple Villageois, sans changer ses pouvoirs.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
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
