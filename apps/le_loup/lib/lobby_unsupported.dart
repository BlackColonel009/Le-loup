import 'package:flutter/material.dart';

class LocalLobbyScreen extends StatelessWidget {
  const LocalLobbyScreen({super.key, this.online = false});
  final bool online;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Salon local')),
    body: const Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'Les salons nécessitent actuellement l’application Android, iOS ou Windows. '
        'Le client navigateur sera ajouté ultérieurement.',
      ),
    ),
  );
}
