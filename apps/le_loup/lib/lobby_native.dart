import 'dart:async';
import 'room_compatibility.dart';
import 'cards/classic_role.dart';
import 'cards/card_gallery.dart';
import 'cards/game_codex.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_host/local_host.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class LocalLobbyScreen extends StatefulWidget {
  const LocalLobbyScreen({super.key});
  @override
  State<LocalLobbyScreen> createState() => _LocalLobbyScreenState();
}

class _LocalLobbyScreenState extends State<LocalLobbyScreen> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _code = TextEditingController();
  LocalHost? _host;
  LobbyClient? _client;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Map<String, dynamic>? _room;
  List<String> _addresses = [];
  bool _busy = false;
  bool _connected = false;
  String? _error;
  Timer? _joinTimeout;
  String? _role;

  Future<void> _keepAwake(bool enabled) async {
    try {
      await WakelockPlus.toggle(enable: enabled);
    } on MissingPluginException {
      // Les tests de widgets n'exécutent pas les plugins natifs.
      debugPrint('Maintien de l’écran indisponible sur cette plateforme.');
    }
  }

  @override
  void dispose() {
    _joinTimeout?.cancel();
    _subscription?.cancel();
    _client?.dispose();
    _host?.dispose();
    _keepAwake(false);
    _name.dispose();
    _address.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    _joinTimeout?.cancel();
    await _subscription?.cancel();
    _subscription = null;
    await _client?.dispose();
    await _host?.dispose();
    _client = null;
    _host = null;
    await _keepAwake(false);
    if (mounted) {
      setState(() {
        _room = null;
        _role = null;
        _connected = false;
        _busy = false;
      });
    }
  }

  Future<void> _start(bool hosting) async {
    if (_name.text.trim().isEmpty || _name.text.trim().length > 24) {
      setState(() => _error = 'Choisis un pseudo de 1 à 24 caractères.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (hosting) {
        final host = LocalHost();
        _host = host;
        await host.start(nickname: _name.text, port: 0);
        final addresses = await host.addresses();
        await _keepAwake(true);
        if (!mounted) {
          await host.dispose();
          return;
        }
        _subscription = host.updates.listen((room) {
          if (mounted) setState(() => _room = room);
        });
        setState(() {
          _addresses = addresses;
          _room = host.snapshot;
          _connected = true;
          _busy = false;
        });
      } else {
        final client = LobbyClient();
        _client = client;
        _subscription = client.events.listen((event) {
          if (!mounted) return;
          if (event['type'] == 'room.snapshot') {
            _joinTimeout?.cancel();
            setState(() {
              _room = event;
              _connected = true;
              _busy = false;
              _error = null;
            });
          } else if (event['type'] == 'game.role') {
            setState(() => _role = event['role'] as String);
          } else if (event['type'] == 'error' ||
              event['type'] == 'disconnected') {
            final message = event['message'] as String;
            if (_room == null) {
              _reset().then((_) {
                if (mounted) setState(() => _error = message);
              });
            } else {
              setState(() {
                _error = message;
                _busy = false;
                if (event['type'] == 'disconnected') {
                  _connected = false;
                  _role = null;
                }
              });
            }
          }
        });
        await client.connect(_address.text, _code.text, _name.text);
        if (!mounted) return;
        if (_busy) {
          _joinTimeout = Timer(const Duration(seconds: 10), () async {
            await _reset();
            if (mounted) {
              setState(
                () => _error =
                    'Le salon ne répond pas. Vérifie le code et le réseau.',
              );
            }
          });
        }
      }
    } catch (_) {
      await _reset();
      if (mounted) {
        setState(
          () => _error =
              'Connexion impossible. Vérifie l’adresse, le Wi-Fi et les autorisations réseau.',
        );
      }
    }
  }

  Future<bool> _confirmLeave() async {
    if (_room == null && !_busy) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_host != null ? 'Fermer le salon ?' : 'Quitter le salon ?'),
        content: Text(
          _host != null
              ? 'Tous les joueurs seront déconnectés.'
              : _room?['phase'] == 'role_reveal'
              ? 'Quitter cet écran efface ta session privée sur cet appareil. Tu ne pourras plus récupérer ton rôle dans cette partie.'
              : 'Tu pourras rejoindre de nouveau avec le même code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Rester'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _room == null && !_busy,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop) return;
      if (await _confirmLeave()) {
        await _reset();
        if (context.mounted) Navigator.pop(context);
      }
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('Le village · Salon local')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_error != null)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!),
                  ),
                ),
              if (_room == null) ..._entry() else ..._lobby(),
            ],
          ),
        ),
      ),
    ),
  );

  List<Widget> _entry() => [
    Text(
      'Rassemble ton village',
      style: Theme.of(context).textTheme.headlineMedium,
    ),
    const SizedBox(height: 12),
    const Text(
      'Connectez vos appareils au même Wi-Fi. Aucun compte ni accès Internet requis.',
    ),
    const SizedBox(height: 24),
    TextField(
      controller: _name,
      enabled: !_busy,
      maxLength: 24,
      decoration: const InputDecoration(
        labelText: 'Ton pseudo',
        border: OutlineInputBorder(),
      ),
    ),
    const SizedBox(height: 12),
    FilledButton.icon(
      onPressed: _busy ? null : () => _start(true),
      icon: const Icon(Icons.cottage_outlined),
      label: const Text('Créer un salon · Je suis le MDJ'),
    ),
    const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Divider(),
    ),
    TextField(
      controller: _address,
      enabled: !_busy,
      autocorrect: false,
      keyboardType: TextInputType.url,
      decoration: const InputDecoration(
        labelText: 'Adresse affichée par le MDJ',
        hintText: '192.168.1.10:8080',
        border: OutlineInputBorder(),
      ),
    ),
    const SizedBox(height: 16),
    TextField(
      controller: _code,
      enabled: !_busy,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      decoration: const InputDecoration(
        labelText: 'Code du salon',
        border: OutlineInputBorder(),
      ),
    ),
    const SizedBox(height: 16),
    OutlinedButton.icon(
      onPressed: _busy ? null : () => _start(false),
      icon: const Icon(Icons.group_add_outlined),
      label: const Text('Rejoindre le village'),
    ),
    if (_busy)
      const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    const SizedBox(height: 24),
    const Text(
      'Créez votre salon, choisissez les rôles et découvrez votre carte secrète. Les nuits et les votes arrivent ensuite.',
    ),
  ];

  Future<void> _reconnect() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _client!.reconnect();
      _joinTimeout?.cancel();
      _joinTimeout = Timer(const Duration(seconds: 10), () {
        if (mounted && !_connected) {
          setState(() {
            _busy = false;
            _error =
                'Le MDJ ne répond pas. Garde cet écran pour conserver ta session et réessaie.';
          });
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Reconnexion impossible. Vérifie le Wi-Fi et réessaie.';
        });
      }
    }
  }

  void _configure(String id, int count) {
    final deck = Map<String, int>.from(_host!.deck);
    deck[id] = count;
    _host!.configure(deck, campOnly: _room!['seer_camp_only'] == true);
  }

  List<Widget> _lobby() {
    if (!hasRoomConfiguration(_room!)) {
      return [
        IncompatibleRoomNotice(
          onLeave: () async {
            if (await _confirmLeave()) await _reset();
          },
        ),
      ];
    }
    final players = (_room!['players'] as List).cast<Map<String, dynamic>>();
    final self = players.where((p) => p['id'] == _client?.id).firstOrNull;
    final ready = players.where((p) => p['ready'] == true).length;
    final started = _room!['phase'] == 'role_reveal';
    final deck = Map<String, int>.from(_room!['deck'] as Map);
    final assignments = _room!['assignments'];
    if (started &&
        _host != null &&
        (assignments is! Map ||
            players.any(
              (player) => !classicRoles.any(
                (role) => role.id == assignments[player['id']],
              ),
            ))) {
      return [
        IncompatibleRoomNotice(
          onLeave: () async {
            if (await _confirmLeave()) await _reset();
          },
        ),
      ];
    }
    final total = deck.values.fold(0, (a, b) => a + b);
    return [
      Text(
        started ? 'Les rôles sont distribués' : 'Le village se rassemble',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 16),
      Text('Code du salon', style: Theme.of(context).textTheme.labelLarge),
      SelectableText(
        _room!['code'] as String,
        style: Theme.of(context).textTheme.displaySmall,
      ),
      Text('Maître du jeu : ${_room!['host']}'),
      OutlinedButton.icon(
        onPressed: () => showGameCodex(context, _room!),
        icon: const Icon(Icons.menu_book),
        label: const Text('Codex et règles de la partie'),
      ),
      if (_host != null) ...[
        const SizedBox(height: 16),
        if (!started) ...[
          const Text('Partage une adresse Wi-Fi et le code avec tes amis :'),
          for (final address in _addresses)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: SelectableText(address),
              trailing: IconButton(
                tooltip: 'Copier l’adresse',
                icon: const Icon(Icons.copy),
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: address)),
              ),
            ),
          if (_addresses.isEmpty)
            const Text(
              'Aucune adresse réseau détectée. Vérifie ta connexion Wi-Fi.',
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Accepter de nouveaux joueurs'),
            value: !(_room!['locked'] as bool),
            onChanged: (value) => _host!.setLocked(!value),
          ),
          const Divider(),
          Text(
            'Composition · $total cartes / ${players.length} joueurs',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text(
            'Chaque modification remet les joueurs en attente de confirmation.',
          ),
          for (final role in classicRoles)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(role.name),
              subtitle: Text(
                role.id == 'villager' || role.id == 'werewolf'
                    ? role.camp
                    : '${role.camp} · Unique',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Retirer ${role.name}',
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: deck[role.id]! > 0
                        ? () => _configure(role.id, deck[role.id]! - 1)
                        : null,
                  ),
                  Text('${deck[role.id]}'),
                  IconButton(
                    tooltip: 'Ajouter ${role.name}',
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed:
                        deck[role.id]! <
                            (role.id == 'villager' || role.id == 'werewolf'
                                ? 20
                                : 1)
                        ? () => _configure(role.id, deck[role.id]! + 1)
                        : null,
                  ),
                ],
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Variante Voyante : camp uniquement'),
            subtitle: const Text('Désactivé : elle découvre le rôle exact.'),
            value: _room!['seer_camp_only'] == true,
            onChanged: (value) => _host!.configure(deck, campOnly: value),
          ),
          if (_room!['launch_error'] != null)
            Text(_room!['launch_error'] as String),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _room!['launch_error'] == null
                ? () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Distribuer les rôles ?'),
                        content: Text(
                          '$total cartes seront distribuées secrètement. La composition sera verrouillée.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Annuler'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Distribuer'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && mounted) {
                      try {
                        _host!.startGame();
                      } catch (error) {
                        setState(() => _error = error.toString());
                      }
                    }
                  }
                : null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Lancer et distribuer les rôles'),
          ),
        ] else
          ExpansionTile(
            title: const Text('Distribution privée · MDJ'),
            subtitle: const Text('À consulter à l’abri des regards'),
            children: [
              for (final player in players)
                ListTile(
                  title: Text(player['nickname'] as String),
                  subtitle: Text(
                    configuredRole(
                      (_room!['assignments'] as Map)[player['id']] as String,
                    ).name,
                  ),
                ),
            ],
          ),
        const SizedBox(height: 12),
        const Text(
          'Garde cette application ouverte au premier plan. Le MDJ ne compte pas parmi les joueurs.',
        ),
        ExpansionTile(
          title: const Text('Diagnostic des connexions'),
          children: [
            for (final line
                in (_room!['connection_diagnostics'] as List? ?? const []))
              ListTile(dense: true, title: Text(line as String)),
          ],
        ),
      ] else ...[
        const SizedBox(height: 16),
        Text(
          _connected
              ? 'Connecté au village'
              : 'Déconnecté — garde cet écran pour récupérer ta session.',
        ),
        if (!_connected)
          FilledButton.icon(
            onPressed: _busy ? null : _reconnect,
            icon: const Icon(Icons.refresh),
            label: Text(_busy ? 'Reconnexion…' : 'Se reconnecter'),
          ),
        if (started && _connected && _role != null)
          FilledButton.icon(
            onPressed: () => showRoleCard(
              context,
              configuredRole(
                _role!,
                seerCampOnly: _room!['seer_camp_only'] == true,
              ),
            ),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Consulter ma carte secrète'),
          ),
        if (!started)
          Text(
            _room!['locked'] == true
                ? 'Les inscriptions sont fermées.'
                : 'Les inscriptions sont ouvertes.',
          ),
      ],
      const SizedBox(height: 24),
      Text(
        started
            ? '${players.length} joueurs · Distribution terminée'
            : '${players.length}/20 joueurs · $ready prêts',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      if (players.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('Les maisons attendent leurs habitants…'),
        ),
      for (final player in players)
        Card(
          child: ListTile(
            leading: Icon(
              player['connected'] != true
                  ? Icons.wifi_off
                  : player['ready'] == true
                  ? Icons.check_circle
                  : Icons.person_outline,
            ),
            title: Text(
              '${player['nickname']}${player['id'] == _client?.id ? ' (toi)' : ''}',
            ),
            subtitle: Text(
              player['connected'] != true
                  ? 'Déconnecté'
                  : started
                  ? 'Dans la partie'
                  : player['ready'] == true
                  ? 'Prêt'
                  : 'En préparation',
            ),
            trailing: _host == null || started
                ? null
                : IconButton(
                    tooltip: 'Retirer ce joueur',
                    icon: const Icon(Icons.person_remove_outlined),
                    onPressed: () => _host!.kick(player['id'] as String),
                  ),
          ),
        ),
      if (_client != null && self != null && !started)
        SwitchListTile(
          title: const Text('Je suis prêt'),
          subtitle: const Text(
            'Je confirme la composition et les règles du Codex.',
          ),
          value: self['ready'] as bool,
          onChanged: _connected ? (value) => _client!.setReady(value) : null,
        ),
      const SizedBox(height: 24),
      Text(
        started
            ? 'Les cartes sont distribuées. Les appels nocturnes et les votes seront ajoutés à la prochaine étape.'
            : 'Pack Classique · 4 joueurs minimum, hors MDJ.',
      ),
      const SizedBox(height: 16),
      OutlinedButton(
        onPressed: () async {
          if (await _confirmLeave()) await _reset();
        },
        child: Text(_host != null ? 'Fermer le salon' : 'Quitter le salon'),
      ),
    ];
  }
}
