import 'package:flutter/material.dart';

class LocalLobbyScreen extends StatelessWidget {
  const LocalLobbyScreen({
    super.key,
    this.online = false,
    this.initialCode,
    this.initialNickname,
    this.communityToken,
    this.autoStart = false,
    this.publicRoom = false,
    this.roomTitle = 'Le village de la nuit',
    this.initialTheme = 'classic',
  });
  final bool online;
  final String? initialCode, initialNickname, communityToken;
  final bool autoStart, publicRoom;
  final String roomTitle, initialTheme;
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
