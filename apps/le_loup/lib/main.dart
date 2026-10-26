import 'package:flutter/material.dart';
import 'lobby.dart';
import 'cards/card_gallery.dart';

void main() => runApp(const LeLoupApp());

class LeLoupApp extends StatelessWidget {
  const LeLoupApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Le Loup',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFFC79752),
      scaffoldBackgroundColor: const Color(0xFF10151E),
      useMaterial3: true,
    ),
    home: const WelcomeScreen(),
  );
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: TavernBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.nightlight_round, size: 72),
                  const SizedBox(height: 24),
                  Text(
                    'Le Loup',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Le village s’endort. À qui faites-vous confiance ?',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LocalLobbyScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.wifi),
                    label: const Text('Jouer en local'),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CardGalleryScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.style_outlined),
                    label: const Text('Découvrir les cartes'),
                  ),
                  const SizedBox(height: 16),
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Notre première étape'),
                          SizedBox(height: 12),
                          Text('Un maître du jeu, un salon et vos amis.'),
                          SizedBox(height: 12),
                          Text(
                            'Crée un salon local ou rejoins tes amis sur le même Wi-Fi. '
                            'Le mode à distance arrivera ensuite.',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Version de développement',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
