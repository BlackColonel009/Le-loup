import 'package:flutter/material.dart';

class LocalLobbyScreen extends StatelessWidget {
  const LocalLobbyScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Salon local')),
    body: const Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'Le salon local nécessite l’application Android, iOS ou Windows. '
        'Le mode web sera disponible pour les parties à distance.',
      ),
    ),
  );
}
