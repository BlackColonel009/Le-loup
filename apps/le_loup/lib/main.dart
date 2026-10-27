import 'package:flutter/material.dart';
import 'lobby.dart';
import 'audio/classic_audio.dart';
import 'audio/audio_settings.dart';
import 'design/game_theme.dart';
import 'design/opening_screen.dart';
import 'cards/card_gallery.dart';
import 'community/community_screen.dart';
import 'store/store_screen.dart';
import 'services/maintenance.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ready = ClassicAudio.instance.initialize().catchError((Object _) {
    ClassicAudio.instance.error = 'Le son est indisponible sur cet appareil.';
  });
  runApp(LeLoupApp(ready: ready));
}

class LeLoupApp extends StatelessWidget {
  const LeLoupApp({super.key, this.ready, this.checkMaintenance});
  final Future<Map<String, dynamic>> Function()? checkMaintenance;
  final Future<void>? ready;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Legende of Wolf',
    debugShowCheckedModeBanner: false,
    theme: GameTheme.classic,
    home: _Entrance(ready: ready, checkMaintenance: checkMaintenance),
  );
}

class _Entrance extends StatefulWidget {
  const _Entrance({this.ready, this.checkMaintenance});
  final Future<Map<String, dynamic>> Function()? checkMaintenance;
  final Future<void>? ready;
  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance> {
  bool _opened = false;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 400),
    child: _opened
        ? WelcomeScreen(
            key: const ValueKey('welcome'),
            checkMaintenance: widget.checkMaintenance,
          )
        : OpeningScreen(
            key: const ValueKey('opening'),
            ready: widget.ready,
            onStart: ClassicAudio.instance.opening,
            onScratch: ClassicAudio.instance.openingScratch,
            onComplete: () {
              if (mounted) setState(() => _opened = true);
            },
          ),
  );
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, this.checkMaintenance});
  final Future<Map<String, dynamic>> Function()? checkMaintenance;
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _checkingGame = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ClassicAudio.instance.welcome();
    });
  }

  Future<void> _play(BuildContext context, {bool online = false}) async {
    if (_checkingGame) return;
    _checkingGame = true;
    final availability =
        await (widget.checkMaintenance?.call() ?? readMaintenance());
    if (!context.mounted) {
      _checkingGame = false;
      return;
    }
    if (availability[online ? 'online_enabled' : 'local_enabled'] == false) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Petite maintenance'),
          content: Text(
            availability['message'] as String? ?? maintenanceMessage,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Compris'),
            ),
          ],
        ),
      );
      _checkingGame = false;
      return;
    }
    ClassicAudio.instance.silence();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LocalLobbyScreen(online: online)),
    );
    if (mounted) ClassicAudio.instance.welcome();
    _checkingGame = false;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 104,
      leading: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Communauté',
            icon: const Icon(Icons.groups_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CommunityScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Boutique',
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const StoreScreen()),
            ),
          ),
        ],
      ),
      actions: const [AudioSettingsButton()],
    ),
    body: TavernBackground(
      dim: .35,
      animate: true,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, size) {
            final wide = size.maxWidth >= 850;
            final identity = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: wide ? 12 : (size.maxHeight * .04).clamp(12, 40),
                ),
                Image.asset(
                  'assets/branding/logo.png',
                  height: wide ? 280 : (size.maxHeight * .24).clamp(130, 210),
                  fit: BoxFit.contain,
                  semanticLabel: 'Logo du jeu Loups-Garous',
                ),
                const SizedBox(height: 10),
                Text(
                  'Legende of Wolf',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: GameTheme.ivory,
                    fontSize: 36,
                  ),
                ),
                const Text(
                  'by Logan R.D',
                  style: TextStyle(color: GameTheme.gold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Le village s’endort.\nÀ qui faites-vous confiance ?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: GameTheme.ivory,
                    fontSize: 17,
                    height: 1.6,
                  ),
                ),
              ],
            );
            final actions = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: GameTheme.ink.withValues(alpha: .78),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: GameTheme.gold.withValues(alpha: .35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Une nuit. Des secrets.',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Rassemble tes amis. Un maître du jeu guide le village ; chacun protège son identité.',
                        style: TextStyle(color: GameTheme.muted, height: 1.5),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () => _play(context),
                        icon: const Icon(Icons.cottage_outlined),
                        label: const Text('Jouer en local'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: () => _play(context, online: true),
                        icon: const Icon(Icons.public),
                        label: const Text('Jouer en ligne'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const CardGalleryScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.style_outlined),
                        label: const Text('Découvrir les cartes'),
                      ),
                      const SizedBox(height: 20),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi, color: GameTheme.gold, size: 16),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Même Wi-Fi · 4 à 20 joueurs + MDJ',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: GameTheme.muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'ÉDITION CLASSIQUE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: GameTheme.gold,
                    fontSize: 11,
                    letterSpacing: 2,
                  ),
                ),
              ],
            );
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(wide ? 48 : 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: wide ? 1080 : 480),
                  child: wide
                      ? Row(
                          children: [
                            Expanded(child: identity),
                            const SizedBox(width: 64),
                            Expanded(child: actions),
                          ],
                        )
                      : Column(
                          children: [
                            identity,
                            const SizedBox(height: 32),
                            actions,
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}
