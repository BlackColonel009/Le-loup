import 'dart:async';
import 'audio/classic_audio.dart';
import 'audio/audio_settings.dart';
import 'design/game_theme.dart';
import 'joining/invite_qr_card.dart';
import 'joining/scan_invitation_screen.dart';
import 'room_compatibility.dart';
import 'night_panel.dart';
import 'village/village_map.dart';
import 'village/village_navigation.dart';
import 'village/village_chat.dart';
import 'village/ceremonies.dart';
import 'cards/classic_role.dart';
import 'cards/card_gallery.dart';
import 'cards/game_codex.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_host/local_host.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class LocalLobbyScreen extends StatefulWidget {
  const LocalLobbyScreen({super.key, this.online = false});
  final bool online;
  @override
  State<LocalLobbyScreen> createState() => _LocalLobbyScreenState();
}

class _LocalLobbyScreenState extends State<LocalLobbyScreen> {
  CardAmbience get _ambience => _room?['visual_pack'] == 'intense'
      ? CardAmbience.intense
      : CardAmbience.classic;
  String? _protectedPlayerId(Map? game) {
    if (game?['is_night'] != true) return null;
    dynamic value;
    if (_host != null) {
      final hostState = _room?['game_host'] as Map?;
      value = hostState?['protected'];
    } else {
      value = _nightPrivate?['guardian_protected_id'];
    }
    return value is String ? value : null;
  }

  Future<void> _showRole(
    BuildContext context,
    ClassicRole role, {
    bool covered = false,
  }) => showRoleCard(context, role, ambience: _ambience, covered: covered);

  Future<void> _editSentences() async {
    final current = (_room?['sentence_options'] as List? ?? NightGame.sentences)
        .cast<String>();
    final fields = current.map((s) => TextEditingController(text: s)).toList();
    final saved = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Personnaliser les sentences'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Huit mises en scène narratives, sans effet sur les pouvoirs.',
                ),
                for (var i = 0; i < fields.length; i++)
                  TextField(
                    controller: fields[i],
                    maxLength: 32,
                    decoration: InputDecoration(labelText: 'Sentence ${i + 1}'),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (fields.any((f) => f.text.trim().isEmpty)) return;
              Navigator.pop(
                dialogContext,
                fields.map((f) => f.text.trim()).toList(),
              );
            },
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );
    // Wait for the dialog route to finish disposing its text fields.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    for (final field in fields) {
      field.dispose();
    }
    if (saved != null && mounted && _host != null) {
      _nightCommand(
        () => _host!.configure(
          Map.of(_host!.deck),
          campOnly: _room?['seer_camp_only'] == true,
          sentences: saved,
        ),
      );
    }
  }

  bool _speakerReminderDismissed = false;
  VillageDestination _destination = VillageDestination.village;
  final _name = TextEditingController();
  String _appearance = 'male';
  bool _femaleFor(dynamic id) => (_room?['players'] as List? ?? const []).any(
    (p) => p['id'] == id && p['appearance'] == 'female',
  );
  final _nameFocus = FocusNode();
  bool _scanning = false;
  final _address = TextEditingController();
  final _code = TextEditingController();
  GameHost? _host;
  LobbyClient? _client;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Map<String, dynamic>? _room;
  List<String> _addresses = [];
  bool _busy = false;
  bool _connected = false;
  String? _error;
  Timer? _joinTimeout;
  String? _role;
  Map<String, dynamic>? _nightPrivate;
  final _phasePanelKey = GlobalKey();
  final _sentenceKey = GlobalKey();
  final _listKey = GlobalKey();
  final _lobbyScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.online) {
      _address.text = const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://127.0.0.1:8000',
      );
    }
  }

  void _continueSentence() {
    setState(() => _destination = VillageDestination.actions);
    final nextNight = _room?['phase'] == 'vote_result';
    final wheel = _sentenceKey.currentContext?.findRenderObject();
    final viewport = _listKey.currentContext?.findRenderObject();
    double? destination;
    if (wheel is RenderBox &&
        viewport is RenderBox &&
        _lobbyScroll.hasClients) {
      final point = wheel.localToGlobal(
        Offset(0, nextNight ? 0 : wheel.size.height),
      );
      destination =
          _lobbyScroll.offset +
          point.dy -
          viewport.localToGlobal(Offset.zero).dy;
    }
    if (nextNight) {
      _nightCommand(() => _host!.continueAfterSentence());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final duration = MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 300);
      if (destination != null && _lobbyScroll.hasClients) {
        final offset = destination.clamp(
          0.0,
          _lobbyScroll.position.maxScrollExtent,
        );
        if (duration == Duration.zero) {
          _lobbyScroll.jumpTo(offset);
        } else {
          _lobbyScroll.animateTo(
            offset,
            duration: duration,
            curve: Curves.easeOut,
          );
        }
        return;
      }
      if (_phasePanelKey.currentContext == null) return;
      Scrollable.ensureVisible(
        _phasePanelKey.currentContext!,
        alignment: 0,
        duration: duration,
      );
    });
  }

  final _villageFeed = ValueNotifier<Map<String, dynamic>>({});
  final _seenDeaths = <String>{};
  final _deathQueue = <Map<String, dynamic>>[];
  bool _deathFeedInitialized = false;
  bool _showingDeaths = false;

  void _refreshVillage() {
    ClassicAudio.instance.room(_room, isHost: _host != null || widget.online);
    _villageFeed.value = {
      'room': _room,
      'private': _nightPrivate,
      'connected': _connected,
      'is_host': _host != null,
    };
  }

  void _receiveDeaths(Map<String, dynamic> room) {
    final events = ((room['game'] as Map?)?['death_events'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    if (!_deathFeedInitialized) {
      _seenDeaths.addAll(events.map((event) => event['id'] as String));
      _deathFeedInitialized = room['game'] != null;
      return;
    }
    for (final event in events) {
      if (_seenDeaths.add(event['id'] as String)) _deathQueue.add(event);
    }
    if (_deathQueue.isEmpty || _showingDeaths) return;
    _showingDeaths = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        while (mounted && _deathQueue.isNotEmpty) {
          final event = _deathQueue.removeAt(0);
          final player = (_room?['players'] as List? ?? [])
              .where((p) => p['id'] == event['player'])
              .firstOrNull;
          final role =
              event['role'] as String? ??
              (event['player'] == _client?.id ? _role : null);
          await showElimination(
            context,
            name: player?['nickname'] as String? ?? 'Joueur',
            role: role,
            cause: event['cause'] as String,
            feminine: _femaleFor(event['player']),
            ambience: _ambience,
          );
        }
      } finally {
        _showingDeaths = false;
      }
    });
  }

  void _openChat() => setState(() => _destination = VillageDestination.chat);

  Widget _section(VillageDestination section) => LayoutBuilder(
    builder: (context, size) => ListView(
      key: section == VillageDestination.actions ? _listKey : ValueKey(section),
      controller: section == VillageDestination.actions ? _lobbyScroll : null,
      padding: const EdgeInsets.all(20),
      children: [
        if (_error != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!),
            ),
          ),
        if (!_connected && (_client != null || _host is OnlineHost))
          ListTile(
            title: const Text('Connexion interrompue'),
            trailing: TextButton(
              onPressed: _busy ? null : _reconnect,
              child: const Text('Reconnecter'),
            ),
          ),
        ..._lobby(
          section,
          mapHeight: section == VillageDestination.village
              ? (size.maxHeight * .68).clamp(290, 650)
              : null,
        ),
      ],
    ),
  );

  Widget _villagePage() => VillageNavigation(
    banner: _host != null && !widget.online && !_speakerReminderDismissed
        ? Material(
            color: GameTheme.panel,
            child: ListTile(
              leading: const Icon(
                Icons.speaker_outlined,
                color: GameTheme.gold,
              ),
              title: const Text(
                'Connecte une enceinte pour plus d’immersion',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Les sons de la partie sont diffusés uniquement sur ton appareil de MDJ.',
              ),
              trailing: IconButton(
                tooltip: 'Fermer le rappel',
                icon: const Icon(Icons.close),
                onPressed: () =>
                    setState(() => _speakerReminderDismissed = true),
              ),
            ),
          )
        : null,
    audioControl: _host != null ? const AudioSettingsButton() : null,
    destination: _destination,
    phase: _room!['phase'] as String,
    isHost: _host != null,
    code: _room!['code'] as String,
    onSelect: (value) => setState(() => _destination = value),
    onCodex: () => showGameCodex(context, _room!),
    village: _section(VillageDestination.village),
    actions: _section(VillageDestination.actions),
    preparation: _section(VillageDestination.preparation),
    chat: VillageChat(
      room: _room!,
      privateState: _nightPrivate,
      isHost: _host != null,
      connected: _connected,
      fullPage: true,
      onSend: (action, revision, text) =>
          _client?.gameAction(action, revision, text: text),
    ),
  );

  void _openHouse(Map<String, dynamic> player) {
    final game = _room!['game'] as Map?;
    String? role;
    if (player['id'] == _client?.id) {
      role = _role;
    } else if (_host != null) {
      role = (_room!['assignments'] as Map?)?[player['id']] as String?;
    } else {
      role = (game?['revealed_roles'] as Map?)?[player['id']] as String?;
    }
    final day = ['day', 'voting', 'vote_result'].contains(_room!['phase']);
    final pack =
        _room!['phase'] == 'wolves' &&
        (_host != null ||
            (_nightPrivate?['is_pack'] == true ||
                    _nightPrivate?['role'] == 'werewolf') &&
                _nightPrivate?['alive'] == true);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Maison de ${player['nickname']}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                player['connected'] == true
                    ? 'Connecté au village'
                    : 'Connexion interrompue · Maison conservée pendant la partie',
              ),
              if (role == null)
                const Text('L’identité de cet habitant reste secrète.'),
              if (role != null)
                FilledButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _showRole(
                      context,
                      configuredRole(
                        role!,
                        feminine: _femaleFor(player['id']),
                        seerCampOnly: _room!['seer_camp_only'] == true,
                      ),
                      covered: player['id'] == _client?.id,
                    );
                  },
                  child: Text(
                    _host != null
                        ? 'Voir la carte · MDJ'
                        : 'Consulter la carte',
                  ),
                ),
              if (day || pack)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _openChat();
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: Text(
                    day ? 'Discussion générale' : 'Discussion de la meute',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

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
    ClassicAudio.instance.silence();
    _joinTimeout?.cancel();
    _subscription?.cancel();
    _client?.dispose();
    _host?.dispose();
    _keepAwake(false);
    _name.dispose();
    _nameFocus.dispose();
    _address.dispose();
    _code.dispose();
    _villageFeed.dispose();
    _lobbyScroll.dispose();
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
        _speakerReminderDismissed = false;
        _destination = VillageDestination.village;
        _role = null;
        _nightPrivate = null;
        _connected = false;
        _busy = false;
      });
      _seenDeaths.clear();
      _deathQueue.clear();
      _deathFeedInitialized = false;
      _refreshVillage();
    }
  }

  Future<void> _start(bool hosting) async {
    if (_busy || _room != null) return;
    if (_name.text.trim().isEmpty || _name.text.trim().length > 24) {
      setState(() => _error = 'Choisis un pseudo de 1 à 24 caractères.');
      _nameFocus.requestFocus();
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (hosting) {
        final GameHost host = widget.online
            ? OnlineHost(_address.text)
            : LocalHost();
        _host = host;
        await host.start(nickname: _name.text, port: 0);
        final addresses = await host.addresses();
        await _keepAwake(true);
        if (!mounted) {
          await host.dispose();
          return;
        }
        _subscription = host.updates.listen((room) {
          if (mounted) {
            setState(() {
              _room = room;
              _connected = room['online_connected'] != false;
              _error = room['online_error'] as String?;
              _busy = false;
            });
            _refreshVillage();
            _receiveDeaths(room);
          }
        });
        setState(() {
          _addresses = addresses;
          _room = host.snapshot;
          _connected = true;
          _busy = false;
        });
        _refreshVillage();
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
            _refreshVillage();
            _receiveDeaths(event);
          } else if (event['type'] == 'game.role') {
            setState(() => _role = event['role'] as String);
            _refreshVillage();
          } else if (event['type'] == 'game.private') {
            setState(() {
              _nightPrivate = event;
              _role = event['role'] as String? ?? _role;
            });
            _refreshVillage();
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
                  _nightPrivate = null;
                }
              });
              _refreshVillage();
            }
          }
        });
        await client.connect(
          widget.online
              ? onlineSocketUri(
                  onlineServerUri(_address.text),
                  _code.text.trim(),
                ).toString()
              : _address.text,
          _code.text,
          _name.text,
          appearance: _appearance,
        );
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
          () => _error = widget.online
              ? 'Connexion au jeu impossible. Vérifie le code et ta connexion Internet.'
              : 'Connexion impossible. Vérifie l’adresse, le Wi-Fi et les autorisations réseau.',
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
              : _room != null && _room!['phase'] != 'lobby'
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
      if (_room != null && _destination != VillageDestination.village) {
        setState(() => _destination = VillageDestination.village);
        return;
      }
      if (await _confirmLeave()) {
        await _reset();
        if (context.mounted) Navigator.pop(context);
      }
    },
    child: Scaffold(
      appBar: _room != null && hasRoomConfiguration(_room!)
          ? null
          : AppBar(
              title: Text(
                widget.online
                    ? 'Le village · En ligne'
                    : 'Le village · Salon local',
              ),
              actions: const [AudioSettingsButton()],
            ),
      body: _room != null && hasRoomConfiguration(_room!)
          ? _villagePage()
          : Center(
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
                    if (_room == null)
                      ..._entry()
                    else
                      ..._lobby(VillageDestination.preparation),
                  ],
                ),
              ),
            ),
    ),
  );

  Future<void> _scanToJoin() async {
    if (_busy || _scanning || _room != null) return;
    if (_name.text.trim().isEmpty || _name.text.trim().length > 24) {
      setState(() => _error = 'Choisis un pseudo de 1 à 24 caractères.');
      _nameFocus.requestFocus();
      return;
    }
    setState(() {
      _scanning = true;
      _error = null;
    });
    LocalInvitation? invitation;
    try {
      invitation = await Navigator.of(context).push<LocalInvitation>(
        MaterialPageRoute(builder: (_) => const ScanInvitationScreen()),
      );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
    if (!mounted || invitation == null || _busy || _room != null) return;
    _address.text = invitation.address;
    _code.text = invitation.code;
    await _start(false);
  }

  void _showInviteQr() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .9,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: InviteQrCard(
              addresses: _addresses,
              code: _room!['code'] as String,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _entry() => [
    Text(
      'Rassemble ton village',
      style: Theme.of(context).textTheme.headlineMedium,
    ),
    const SizedBox(height: 12),
    Text(
      widget.online
          ? 'Retrouve tes amis sur LegendeOfWolf.com et rejoins leur village avec le code du salon.'
          : 'Connectez vos appareils au même Wi-Fi. Aucun compte ni accès Internet requis.',
    ),
    const SizedBox(height: 24),
    TextField(
      controller: _name,
      focusNode: _nameFocus,
      enabled: !_busy,
      maxLength: 24,
      decoration: const InputDecoration(
        labelText: 'Ton pseudo',
        border: OutlineInputBorder(),
      ),
    ),
    const SizedBox(height: 12),
    DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: _appearance,
      decoration: const InputDecoration(
        labelText: 'Sexe / apparence de la carte',
        helperText: 'Choix visuel uniquement, sans effet sur les pouvoirs.',
      ),
      items: const [
        DropdownMenuItem(value: 'male', child: Text('Masculin · Villageois')),
        DropdownMenuItem(value: 'female', child: Text('Féminin · Villageoise')),
      ],
      onChanged: _busy
          ? null
          : (value) => setState(() => _appearance = value ?? 'male'),
    ),
    if (widget.online) ...[
      const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'LegendeOfWolf.com',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      const SizedBox(height: 16),
    ],
    FilledButton.icon(
      onPressed: _busy ? null : () => _start(true),
      icon: const Icon(Icons.cottage_outlined),
      label: const Text('Créer un salon · Je suis le MDJ'),
    ),
    const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Divider(),
    ),
    if (!widget.online)
      FilledButton.icon(
        onPressed: _busy || _scanning ? null : _scanToJoin,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scanner pour rejoindre'),
      ),
    const SizedBox(height: 8),
    Text(
      widget.online
          ? 'Pour rejoindre, saisis le code à six chiffres partagé par le MDJ.'
          : 'Choisis ton pseudo, puis scanne le QR du MDJ. Ou saisis son adresse et son code ci-dessous.',
    ),
    const SizedBox(height: 20),
    if (!widget.online)
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
      'Créez votre salon, choisissez les rôles et découvrez votre carte secrète. Le MDJ guide les nuits, les débats et les votes.',
    ),
  ];

  Future<void> _reconnect() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_host is OnlineHost) {
        await (_host as OnlineHost).reconnect();
        if (mounted) {
          setState(() {
            _connected = true;
            _busy = false;
            _error = null;
          });
        }
        return;
      }
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
          _error = widget.online
              ? 'Reconnexion impossible. Vérifie Internet et réessaie.'
              : 'Reconnexion impossible. Vérifie le Wi-Fi et réessaie.';
        });
      }
    }
  }

  void _configure(String id, int count) {
    final deck = Map<String, int>.from(_host!.deck);
    deck[id] = count;
    _host!.configure(deck, campOnly: _room!['seer_camp_only'] == true);
  }

  void _nightCommand(VoidCallback command) {
    try {
      command();
      if (mounted && _error != null) setState(() => _error = null);
    } catch (error) {
      setState(() => _error = error.toString());
    }
  }

  List<Widget> _lobby(VillageDestination section, {double? mapHeight}) {
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
    final started = _room!['phase'] != 'lobby';
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
    final game = _room!['game'] as Map?;
    final day = ['day', 'voting', 'vote_result'].contains(_room!['phase']);
    final pack =
        _room!['phase'] == 'wolves' &&
        (_host != null ||
            (_nightPrivate?['is_pack'] == true ||
                    _nightPrivate?['role'] == 'werewolf') &&
                _nightPrivate?['alive'] == true);
    List messages = [];
    if (day) {
      messages = game?['day_messages'] as List? ?? [];
    } else if (pack && _host != null) {
      messages = (_room!['game_host'] as Map?)?['wolf_messages'] as List? ?? [];
    } else if (pack) {
      messages = _nightPrivate?['messages'] as List? ?? [];
    }
    final bubbleAuthors = messages
        .map((message) => message['author'] as String)
        .toSet();
    return [
      if (section == VillageDestination.preparation) ...[
        Text(
          !started
              ? 'Le village se rassemble'
              : _room!['phase'] == 'ended'
              ? 'La partie est terminée'
              : day
              ? 'Le village est en conseil'
              : _room!['phase'] == 'role_reveal'
              ? 'Découvrez vos cartes'
              : 'Le village vit son histoire',
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
        const SizedBox(height: 16),
      ],
      if (section == VillageDestination.village) ...[
        VillageMap(
          protectedPlayerId: _protectedPlayerId(game),
          displayHeight: mapHeight,
          room: _room!,
          selfId: _client?.id,
          bubbleAuthors: bubbleAuthors,
          onHouse: _openHouse,
          onChat: _openChat,
        ),
        const SizedBox(height: 20),
        Text(
          started
              ? (day
                    ? 'Le conseil vous attend'
                    : 'Le village retient son souffle')
              : 'Votre histoire commence ici',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => setState(
            () => _destination = !started
                ? VillageDestination.preparation
                : day
                ? VillageDestination.council
                : VillageDestination.actions,
          ),
          icon: Icon(
            !started
                ? Icons.tune
                : day
                ? Icons.forum_outlined
                : Icons.nights_stay_outlined,
          ),
          label: Text(
            !started
                ? 'Préparer la partie'
                : day
                ? 'Rejoindre le conseil'
                : _host != null
                ? 'Conduire la nuit'
                : 'Voir mon action',
          ),
        ),
        if (!started && _host != null && !widget.online)
          OutlinedButton.icon(
            onPressed: _showInviteQr,
            icon: const Icon(Icons.qr_code_2),
            label: const Text('Inviter par QR code'),
          ),
        if (started && _role != null)
          OutlinedButton.icon(
            onPressed: () => _showRole(
              context,
              configuredRole(
                _role!,
                feminine: _femaleFor(_client?.id),
                seerCampOnly: _room!['seer_camp_only'] == true,
              ),
              covered: true,
            ),
            icon: const Icon(Icons.style_outlined),
            label: const Text('Ma carte secrète'),
          ),
      ],
      if (section == VillageDestination.actions) ...[
        if (!started)
          const Text('La partie commencera après la préparation du salon.'),
        if (game != null &&
            (game['vote_result'] as Map?)?['eliminated'] != null)
          SentenceWheel(
            intense: _ambience == CardAmbience.intense,
            key: _sentenceKey,
            game: game.cast<String, dynamic>(),
            isHost: _host != null,
            onSpin: () => _nightCommand(() => _host!.spinSentence()),
            onContinue: _host == null ? null : _continueSentence,
            name: (id) =>
                players
                    .where((player) => player['id'] == id)
                    .map((player) => player['nickname'] as String)
                    .firstOrNull ??
                'Joueur',
          ),
        if (started)
          NightPanel(
            key: _phasePanelKey,
            showDayChat: false,
            room: _room!,
            privateState: _nightPrivate,
            isHost: _host != null,
            connected: _connected,
            onStart: (seconds) =>
                _nightCommand(() => _host!.startNight(seconds: seconds)),
            onAdvance: () => _nightCommand(() => _host!.advanceNight()),
            onCallNight: (action) =>
                _nightCommand(() => _host!.callNight(action)),
            onFinishNight: () => _nightCommand(() => _host!.finishNight()),
            onPause: () => _nightCommand(() => _host!.pauseNight()),
            onResume: () => _nightCommand(() => _host!.resumeNight()),
            onVote: (seconds) =>
                _nightCommand(() => _host!.startVote(seconds: seconds)),
            onChat: (value) => _nightCommand(() => _host!.setDayChat(value)),
            onAction: (action, revision, {target, save, kill, text, targets}) =>
                _client!.gameAction(
                  action,
                  revision,
                  target: target,
                  save: save,
                  kill: kill,
                  text: text,
                  targets: targets,
                ),
          ),
      ],
      if (section == VillageDestination.preparation) ...[
        if (_host != null) ...[
          const SizedBox(height: 16),
          if (!started) ...[
            if (!widget.online)
              InviteQrCard(
                addresses: _addresses,
                code: _room!['code'] as String,
              ),
            if (widget.online)
              OutlinedButton.icon(
                onPressed: () => Clipboard.setData(
                  ClipboardData(
                    text:
                        'LegendeOfWolf.com\nRejoins mon village dans Legende of Wolf !\nCode : ${_room!['code']}',
                  ),
                ),
                icon: const Icon(Icons.copy),
                label: const Text('Copier l’invitation en ligne'),
              ),
            const SizedBox(height: 12),
            Text(
              widget.online
                  ? 'Partage le code du salon avec tes amis sur LegendeOfWolf.com.'
                  : 'Partage une adresse Wi-Fi et le code avec tes amis :',
            ),
            if (!widget.online)
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
            if (!widget.online && _addresses.isEmpty)
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
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _room?['visual_pack'] as String? ?? 'classic',
              decoration: const InputDecoration(
                labelText: 'Habillage du salon · gratuit',
              ),
              items: const [
                DropdownMenuItem(value: 'classic', child: Text('Classique')),
                DropdownMenuItem(
                  value: 'intense',
                  child: Text('Intense Premium · Gratuit'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  _host!.configure(
                    Map.of(_host!.deck),
                    campOnly: _room?['seer_camp_only'] == true,
                    pack: value,
                  );
                }
              },
            ),
            const Text(
              'Même jeu, mêmes pouvoirs. Le thème du MDJ est appliqué à tous les joueurs.',
            ),
            OutlinedButton.icon(
              onPressed: _editSentences,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Modifier les sentences de la roue'),
            ),
            Text(
              'Composition · $total cartes / ${players.length} joueurs',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Chaque modification remet les joueurs en attente de confirmation.',
            ),
            for (final role in playableClassicRoles)
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
                      onPressed: (deck[role.id] ?? 0) > 0
                          ? () => _configure(role.id, (deck[role.id] ?? 0) - 1)
                          : null,
                    ),
                    Text('${deck[role.id] ?? 0}'),
                    IconButton(
                      tooltip: 'Ajouter ${role.name}',
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed:
                          (deck[role.id] ?? 0) <
                              (role.id == 'villager' || role.id == 'werewolf'
                                  ? 20
                                  : 1)
                          ? () => _configure(role.id, (deck[role.id] ?? 0) + 1)
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Révéler les cartes à l’élimination'),
              subtitle: const Text(
                'Sinon les autres joueurs voient un dos de carte. Ce choix est public au Codex.',
              ),
              value: _room!['reveal_roles_on_death'] == true,
              onChanged: (value) => _host!.configure(
                deck,
                campOnly: _room!['seer_camp_only'] == true,
                revealOnDeath: value,
              ),
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
                        feminine: _femaleFor(player['id']),
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
              onPressed: () => _showRole(
                context,
                configuredRole(
                  _role!,
                  feminine: _femaleFor(_client?.id),
                  seerCampOnly: _room!['seer_camp_only'] == true,
                ),
                covered: true,
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
                    : started &&
                          (_room!['game'] as Map?)?['alive_ids'] is List &&
                          !((_room!['game'] as Map)['alive_ids'] as List)
                              .contains(player['id'])
                    ? 'Éliminé'
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
                      onPressed: () async {
                        try {
                          await _host!.kick(player['id'] as String);
                        } catch (_) {
                          if (mounted) {
                            setState(
                              () => _error = 'Impossible de retirer ce joueur.',
                            );
                          }
                        }
                      },
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
              ? 'Le MDJ dirige les appels, la discussion et les votes du village.'
              : 'Pack ${_ambience == CardAmbience.intense ? 'Intense Premium · Gratuit' : 'Classique'} · 4 joueurs minimum, hors MDJ.',
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () async {
            if (await _confirmLeave()) await _reset();
          },
          child: Text(_host != null ? 'Fermer le salon' : 'Quitter le salon'),
        ),
      ],
    ];
  }
}
