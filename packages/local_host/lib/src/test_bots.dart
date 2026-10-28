import 'dart:async';
import 'dart:math';
import 'client.dart';
import 'server.dart';

/// Makes decisions from a player's public and private views only.
/// Never accepts a host snapshot, assignments, or another player's private view.
class BotDecisions {
  BotDecisions({Random? random}) : _random = random ?? Random();
  final Random _random;
  final Map<String, String> _knownCamps = {};
  String? _lastRole;
  int? _roleVersion;

  Map<String, dynamic>? next(
    String id,
    Map<String, dynamic> game,
    Map<String, dynamic> own,
  ) {
    if (own['phase_revision'] != game['phase_revision'] ||
        game['paused'] == true ||
        game['closed'] == true)
      return null;
    if (_lastRole != own['role'] || _roleVersion != own['role_version']) {
      _knownCamps.clear();
      _lastRole = own['role'] as String?;
      _roleVersion = own['role_version'] as int?;
    }
    void remember(dynamic vision) {
      if (vision is! Map || vision['target'] is! String) return;
      final value = vision['value'];
      if (vision['kind'] == 'camp') {
        _knownCamps[vision['target']] = '$value';
      } else if (['werewolf', 'alpha_wolf', 'wolf_father'].contains(value)) {
        _knownCamps[vision['target']] = 'wolves';
      }
    }

    remember(own['vision']);
    final alive = List<String>.from(game['alive_ids'] as List? ?? []);
    final others = alive.where((p) => p != id).toList()..sort();
    final pack = List<String>.from(own['pack'] as List? ?? []);
    final lover = own['lover'];
    String? choose(List<String> choices) {
      if (choices.isEmpty) return null;
      final preferred = choices.where((p) => p != lover).toList();
      final pool = preferred.isEmpty ? choices : preferred;
      return pool[_random.nextInt(pool.length)];
    }

    Map<String, dynamic> action(
      String name, {
      String? target,
      List<String>? targets,
    }) => {
      'action': name,
      'phase_revision': game['phase_revision'],
      if (target != null) 'target': target,
      if (targets != null) 'targets': targets,
    };
    if (own['can_vote'] == true && own['vote_submitted'] != true) {
      final candidates = others.where((p) => !pack.contains(p)).toList();
      final suspected = candidates
          .where((p) => _knownCamps[p] == 'wolves')
          .toList();
      return action(
        'vote.cast',
        target: choose(suspected.isEmpty ? candidates : suspected),
      );
    }
    if (own['can_act'] != true) return null;
    final phase = game['phase'];
    // Reactions may belong to an eliminated player (hunter, scapegoat, mayor).
    if (phase == 'hunter')
      return action('hunter.shoot', target: choose(others));
    final variants = (own['variant_abilities'] as List? ?? []).cast<Map>();
    if (variants.isNotEmpty) {
      final ability = variants.first;
      final choices = List<String>.from(ability['targets'] as List)
        ..shuffle(_random);
      final count = ability['min'] as int;
      if (choices.length >= count) {
        return action(
          ability['action'] as String,
          targets: choices.take(count).toList(),
        );
      }
    }
    final ability = own['ability'];
    if (ability is Map) {
      final choices = List<String>.from(ability['targets'] as List)
        ..shuffle(_random);
      final count = ability['min'] as int;
      if (choices.length >= count) {
        return action(
          ability['action'] as String,
          targets: choices.take(count).toList(),
        );
      }
      return ability['can_pass'] == true ? action('night.pass') : null;
    }
    if (phase == 'seer') {
      final unexplored = others
          .where((p) => !_knownCamps.containsKey(p))
          .toList();
      return action(
        'seer.inspect',
        target: choose(unexplored.isEmpty ? others : unexplored),
      );
    }
    if (phase == 'wolves') {
      final targets = others.where((p) => !pack.contains(p)).toList()..sort();
      // Visible pack ballots allow consensus without reading any hidden roles.
      final votes = own['choices'] as Map? ?? {};
      final proposed = votes.values
          .whereType<String>()
          .where(targets.contains)
          .toList();
      proposed.sort();
      final target = proposed.isNotEmpty ? proposed.first : targets.firstOrNull;
      return target == null ? null : action('wolves.choose', target: target);
    }
    if (phase == 'witch') {
      final suspects = others.where((p) => _knownCamps[p] == 'wolves').toList();
      // Occasionally use poison to exercise that resolution as well.
      final kill =
          own['death_available'] == true &&
              (suspects.isNotEmpty || _random.nextInt(4) == 0)
          ? choose(suspects.isEmpty ? others : suspects)
          : null;
      return {
        ...action('witch.potions'),
        'save': own['life_available'] == true && own['victim'] != null,
        'kill': kill,
      };
    }
    return null;
  }
}

/// Device-local simulation. No community accounts, invitations or statistics.
/// The application must validate the administrator session before creating it.
class TestBotTable {
  TestBotTable(this.host);
  final LocalHost host;
  final _bots = <_TestBot>[];
  bool _disposed = false;
  int _sequence = 0;
  bool _paused = false;
  Duration _delay = const Duration(milliseconds: 900);
  int get count => _bots.where((bot) => bot.connected).length;
  bool get paused => _paused;
  set paused(bool value) {
    _paused = value;
  }

  set delay(Duration value) {
    _delay = value;
  }

  Future<void> add(int count) async {
    if (_disposed || host.started)
      throw StateError('Ajout impossible pendant la partie.');
    for (var n = 0; n < count; n++) {
      if ((host.snapshot['players'] as List).length >= 20) break;
      final bot = _TestBot(this, 'Bot ${++_sequence}');
      _bots.add(bot);
      try {
        await bot.connect();
        if (_disposed) {
          await bot.dispose();
          return;
        }
        host.markTestPlayer(bot.client.id!);
      } catch (_) {
        _bots.remove(bot);
        await bot.dispose();
        rethrow;
      }
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await Future.wait(_bots.map((bot) => bot.dispose()));
    _bots.clear();
  }
}

class _TestBot {
  _TestBot(this.table, this.name);
  final TestBotTable table;
  final String name;
  final client = LobbyClient();
  final policy = BotDecisions();
  final _joined = Completer<void>();
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _timer;
  Map<String, dynamic> _game = {}, _own = {};
  final Set<String> _sent = {};
  bool connected = false;
  bool _lobby = true, _ready = false;
  bool _disposed = false;

  Future<void> connect() async {
    _subscription = client.events.listen((event) {
      switch (event['type']) {
        case 'room.joined':
          connected = true;
          client.setReady(true);
          if (!_joined.isCompleted) _joined.complete();
        case 'room.snapshot':
          _game = Map<String, dynamic>.from(event['game'] as Map? ?? {});
          _lobby = event['phase'] == 'lobby';
          final self = (event['players'] as List? ?? [])
              .whereType<Map>()
              .where((p) => p['id'] == client.id)
              .firstOrNull;
          _ready = self?['ready'] == true;
        case 'game.private':
          _own = event;
        case 'disconnected':
          connected = false;
          _timer?.cancel();
          if (!_joined.isCompleted)
            _joined.completeError(StateError('Connexion du bot interrompue.'));
        case 'error':
          if (!_joined.isCompleted)
            _joined.completeError(StateError('${event['message']}'));
      }
    });
    // Attach the timeout before opening the socket, including transport errors.
    final joined = _joined.future.timeout(const Duration(seconds: 10));
    try {
      await client.connect(
        '127.0.0.1:${table.host.port}',
        table.host.code,
        name,
      );
    } catch (error, stack) {
      if (!_joined.isCompleted) _joined.completeError(error, stack);
    }
    await joined;
    if (_disposed) return;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  DateTime _next = DateTime.now();
  void _tick() {
    if (_disposed ||
        !connected ||
        table.paused ||
        DateTime.now().isBefore(_next))
      return;
    _next = DateTime.now().add(table._delay);
    if (_lobby) {
      if (!_ready) client.setReady(true);
      return;
    }
    if (_game['phase'] == 'ended') {
      _timer?.cancel();
      return;
    }
    final id = client.id;
    if (id == null) return;
    final move = policy.next(id, _game, _own);
    if (move == null) return;
    final key = '${move['phase_revision']}:${move['action']}';
    if (!_sent.add(key)) return;
    if (_sent.length > 100) _sent.remove(_sent.first);
    client.gameAction(
      move['action'] as String,
      move['phase_revision'] as int,
      target: move['target'] as String?,
      targets: (move['targets'] as List?)?.cast<String>(),
      save: move['save'] as bool?,
      kill: move['kill'] as String?,
    );
    // Scripted messages are deliberately neutral: no hidden role disclosure.
    if (move['action'] == 'vote.cast' && _game['chat_open'] == true) {
      client.gameAction(
        'day.chat',
        move['phase_revision'] as int,
        text: 'Je garde un œil sur les votes. Mon choix est fait.',
      );
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    connected = false;
    _timer?.cancel();
    await _subscription?.cancel();
    await client.dispose();
  }
}
