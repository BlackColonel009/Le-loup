import 'package:flutter/material.dart';
import 'lobby.dart';
import 'audio/classic_audio.dart';
import 'design/game_theme.dart';
import 'design/opening_screen.dart';
import 'cards/card_gallery.dart';
import 'services/maintenance.dart';
import 'services/app_update_gate.dart';
import 'village/horror_ambience.dart';
import 'social/online_hub.dart';
import 'social/admin_bot_launcher.dart';
import 'store/collector_welcome.dart';
import 'services/immersion_preferences.dart';
import 'challenges/challenge_discovery.dart';
import 'challenges/challenges_screen.dart';
import 'design/home_top_bar.dart';
import 'design/app_version_label.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ImmersionPreferences.instance.initialize().catchError((Object _) {});
  await HorrorPreferences.instance.initialize().catchError((Object _) {});
  final ready = ClassicAudio.instance.initialize().catchError((Object _) {
    ClassicAudio.instance.error = 'Le son est indisponible sur cet appareil.';
  });
  runApp(MordevielApp(ready: ready));
}

class MordevielApp extends StatelessWidget {
  const MordevielApp({super.key, this.ready, this.checkMaintenance});
  final Future<Map<String, dynamic>> Function()? checkMaintenance;
  final Future<void>? ready;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Mordeviel',
    debugShowCheckedModeBanner: false,
    theme: GameTheme.classic,
    builder: (context, child) => ListenableBuilder(
      listenable: ImmersionPreferences.instance,
      builder: (context, _) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations:
              MediaQuery.disableAnimationsOf(context) ||
              ImmersionPreferences.instance.lightEffects,
        ),
        child: child!,
      ),
    ),
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
        ? AppUpdateGate(
            child: WelcomeScreen(
              key: const ValueKey('welcome'),
              checkMaintenance: widget.checkMaintenance,
              showCollectorOnLaunch: true,
            ),
          )
        : ListenableBuilder(
            key: const ValueKey('opening'),
            listenable: ClassicAudio.instance,
            builder: (context, _) => OpeningScreen(
              ready: widget.ready,
              volume: ClassicAudio.instance.muted
                  ? 0
                  : ClassicAudio.instance.effectLevel,
              onStart: ClassicAudio.instance.silence,
              onComplete: () {
                if (mounted) setState(() => _opened = true);
              },
            ),
          ),
  );
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({
    super.key,
    this.checkMaintenance,
    this.showCollectorOnLaunch = false,
  });
  final bool showCollectorOnLaunch;
  final Future<Map<String, dynamic>> Function()? checkMaintenance;
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int _accountRevision = 0;
  bool _checkingGame = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ClassicAudio.instance.welcome();
        if (widget.showCollectorOnLaunch) _collectorAfterHowl();
      }
    });
  }

  Future<void> _collectorAfterHowl() async {
    await ClassicAudio.instance.welcomeHowlFinished;
    if (mounted) await showChallengeDiscovery(context);
    if (mounted) await showDailyCollector(context);
  }

  Future<void> _openChallenges() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const ChallengesScreen()));
    if (mounted) setState(() => _accountRevision++);
  }

  Future<void> _play(
    BuildContext context, {
    bool online = false,
    String? testNickname,
  }) async {
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
      MaterialPageRoute<void>(
        builder: (_) => online
            ? const OnlineHubScreen()
            : LocalLobbyScreen(
                initialNickname: testNickname,
                autoStart: testNickname != null,
              ),
      ),
    );
    if (mounted) {
      ClassicAudio.instance.welcome();
      setState(() => _accountRevision++);
    }
    _checkingGame = false;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: HomeTopBar(
      onAccountChanged: () {
        if (mounted) setState(() => _accountRevision++);
      },
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
                ChallengesHomeShortcut(onTap: _openChallenges),
                const SizedBox(height: 12),
                SizedBox(
                  height: wide ? 12 : (size.maxHeight * .04).clamp(12, 40),
                ),
                Image.asset(
                  'assets/branding/logo.png',
                  height: wide ? 280 : (size.maxHeight * .24).clamp(130, 210),
                  fit: BoxFit.contain,
                  semanticLabel: 'Logo de Mordeviel Legendary',
                ),
                const SizedBox(height: 10),
                Text(
                  'Mordeviel',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: GameTheme.ivory,
                    fontSize: 36,
                  ),
                ),
                const Text(
                  'LEGENDARY',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: GameTheme.gold,
                    fontSize: 16,
                    letterSpacing: 4,
                  ),
                ),
                const SizedBox(height: 6),
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
                      AdminBotLauncher(
                        revision: _accountRevision,
                        onStart: (nickname) =>
                            _play(context, testNickname: nickname),
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
                const SizedBox(height: 8),
                const AppVersionLabel(),
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
