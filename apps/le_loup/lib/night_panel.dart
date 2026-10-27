import 'dart:async';
import 'package:flutter/material.dart';
import 'cards/classic_role.dart';

typedef SendNightAction =
    void Function(
      String action,
      int revision, {
      String? target,
      bool? save,
      String? kill,
      String? text,
      List<String>? targets,
    });

class NightPanel extends StatefulWidget {
  const NightPanel({
    super.key,
    required this.room,
    this.privateState,
    required this.isHost,
    required this.connected,
    required this.onStart,
    required this.onAdvance,
    required this.onPause,
    required this.onResume,
    required this.onAction,
    this.showDayChat = true,
    this.onVote,
    this.onChat,
    this.onCallNight,
    this.onFinishNight,
  });
  final bool showDayChat;
  final Map<String, dynamic> room;
  final Map<String, dynamic>? privateState;
  final bool isHost;
  final bool connected;
  final void Function(int seconds) onStart;
  final VoidCallback onAdvance;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final SendNightAction onAction;
  final void Function(int seconds)? onVote;
  final ValueChanged<bool>? onChat;
  final ValueChanged<String>? onCallNight;
  final VoidCallback? onFinishNight;
  @override
  State<NightPanel> createState() => _NightPanelState();
}

class _NightPanelState extends State<NightPanel> {
  late final Timer _ticker;
  final _elapsed = Stopwatch()..start();
  final _message = TextEditingController();
  String? _target;
  String? _kill;
  bool _save = false;
  int _seconds = 120;
  int _voteSeconds = 120;
  String? _voteChoice;
  final Set<String> _chosenTargets = {};
  Map<String, dynamic>? get game =>
      (widget.room['game'] as Map?)?.cast<String, dynamic>();
  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant NightPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.room, widget.room)) _elapsed.reset();
    if ((oldWidget.room['game'] as Map?)?['phase_revision'] !=
            game?['phase_revision'] ||
        oldWidget.privateState?['role_version'] !=
            widget.privateState?['role_version']) {
      _target = null;
      _kill = null;
      _save = false;
      _message.clear();
      _voteChoice = null;
      _chosenTargets.clear();
    }
  }

  @override
  void dispose() {
    _ticker.cancel();
    _message.dispose();
    super.dispose();
  }

  String name(dynamic id) =>
      (widget.room['players'] as List)
          .where((p) => p['id'] == id)
          .map((p) => p['nickname'] as String)
          .firstOrNull ??
      'Personne';

  void send(
    String action, {
    String? target,
    bool? save,
    String? kill,
    String? text,
    List<String>? targets,
  }) => widget.onAction(
    action,
    game!['phase_revision'] as int,
    target: target,
    save: save,
    kill: kill,
    text: text,
    targets: targets,
  );

  Widget abilityPanel(Map ability) {
    final ids = (ability['targets'] as List).cast<String>();
    final minimum = ability['min'] as int;
    final maximum = ability['max'] as int;
    final selected = _chosenTargets.where(ids.contains).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        Text(
          ability['label'] as String,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        if (maximum > 0) ...[
          const SizedBox(height: 8),
          Text(
            minimum == maximum
                ? 'Choisis $minimum joueur(s) distinct(s).'
                : 'Choisis de $minimum à $maximum joueurs.',
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in ids)
                FilterChip(
                  label: Text(
                    '${name(id)}${id == widget.privateState?['id'] ? ' (moi)' : ''}',
                  ),
                  selected: selected.contains(id),
                  onSelected:
                      !selected.contains(id) && selected.length >= maximum
                      ? null
                      : (value) => setState(() {
                          if (value) {
                            _chosenTargets.add(id);
                          } else {
                            _chosenTargets.remove(id);
                          }
                        }),
                ),
            ],
          ),
          Text('${selected.length} / $maximum sélectionné(s)'),
        ],
        FilledButton(
          onPressed: selected.length >= minimum && selected.length <= maximum
              ? () => send(ability['action'] as String, targets: selected)
              : null,
          child: Text(ability['label'] as String),
        ),
        if (ability['can_pass'] == true)
          TextButton(
            onPressed: () => send('night.pass'),
            child: const Text('Passer mon action'),
          ),
      ],
    );
  }

  Widget choose(
    String label,
    List<String> ids,
    String? value,
    ValueChanged<String?> changed, {
    bool optional = false,
  }) => DropdownButtonFormField<String>(
    key: ValueKey('$label-${game!['phase_revision']}'),
    initialValue: ids.contains(value) ? value : null,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    items: [
      if (optional)
        const DropdownMenuItem(value: '', child: Text('Ne pas utiliser')),
      for (final id in ids) DropdownMenuItem(value: id, child: Text(name(id))),
    ],
    onChanged: (value) => changed(value == '' ? null : value),
  );

  Future<void> advance() async {
    if (game!['closed'] != true &&
        (game!['timed'] == true ||
            [
              'seer',
              'wolves',
              'witch',
              'hunter',
              'voting',
            ].contains(game!['phase']))) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Terminer cet appel ?'),
          content: const Text(
            'Les choix confirmés seront conservés. Les actions manquantes ne seront pas exécutées.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Attendre'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuer'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    widget.onAdvance();
  }

  @override
  Widget build(BuildContext context) {
    final state = game;
    if (state == null) return const SizedBox.shrink();
    final phase = state['phase'] as String;
    final private = widget.privateState;
    final matching = private?['phase_revision'] == state['phase_revision'];
    final canActBase =
        widget.connected && matching && private?['can_act'] == true;
    final alive = (state['alive_ids'] as List).cast<String>();
    final ownId = private?['id'];
    final targets = alive.where((id) => id != ownId).toList();
    final remaining =
        ((state['remaining_ms'] as int? ?? 0) -
                (state['paused'] == true ? 0 : _elapsed.elapsedMilliseconds))
            .clamp(0, 3600000);
    final canAct = canActBase && remaining > 0 && state['paused'] != true;
    final timed =
        state['timed'] as bool? ??
        ['seer', 'wolves', 'witch', 'hunter', 'voting'].contains(phase);
    final daytime = ['day', 'voting', 'vote_result'].contains(phase);
    final canVote =
        widget.connected &&
        matching &&
        private?['can_vote'] == true &&
        remaining > 0 &&
        state['paused'] != true;
    final night =
        state['is_night'] as bool? ??
        ['sleep', 'seer', 'wolves', 'witch'].contains(phase);
    final host = (widget.room['game_host'] as Map?) ?? const {};
    final nextLabel = switch (phase) {
      'dawn' =>
        host['pending_hunter'] != null
            ? 'Appeler le Chasseur'
            : 'Ouvrir la journée',
      'hunter' => 'Terminer les réactions',
      'scapegoat' => 'Terminer le choix des électeurs',
      'voting' => 'Clore et révéler le scrutin',
      _ => 'Continuer',
    };
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 500),
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: night ? const Color(0xFF18213C) : const Color(0xFF3B3020),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF98764B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                night ? Icons.nights_stay_outlined : Icons.wb_sunny_outlined,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${night ? 'Nuit' : 'Jour'} ${state['night']} · ${phase == 'role_reveal'
                      ? 'Préparation'
                      : phase == 'ended'
                      ? 'Fin de partie'
                      : night
                      ? 'Le village dort'
                      : 'Le village se réveille'}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(
              state['announcement'] as String,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (timed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                state['paused'] == true
                    ? 'Chronomètre en pause'
                    : state['closed'] == true || remaining == 0
                    ? 'Temps écoulé · Le MDJ peut poursuivre'
                    : '${(remaining / 1000).ceil()} secondes restantes',
              ),
            ),
          if ([
            'dawn',
            'hunter',
            'day',
            'vote_result',
            'ended',
          ].contains(phase)) ...[
            const SizedBox(height: 12),
            Text(
              (state['deaths'] as List).isEmpty
                  ? phase == 'vote_result'
                        ? 'Personne n’est éliminé au vote.'
                        : 'Aucun décès à annoncer.'
                  : 'Joueurs éliminés : ${(state['deaths'] as List).map(name).join(', ')}',
            ),
          ],
          if (phase == 'day')
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'Débattez ensemble. Le MDJ ouvre le vote quand le village est prêt.',
              ),
            ),
          if (phase == 'ended') ...[
            const SizedBox(height: 12),
            for (final entry in (state['revealed_roles'] as Map).entries)
              Text(
                '${name(entry.key)} : ${configuredRole(entry.value as String).name}',
              ),
          ],
          if (phase == 'voting')
            Text(
              '${state['votes_received']} / ${state['vote_eligible_count'] ?? alive.length} bulletins reçus · Résultats encore secrets.',
            ),
          if (state['vote_result'] is Map &&
              ['hunter', 'vote_result', 'ended'].contains(phase)) ...[
            const Divider(),
            const Text(
              'Résultat du scrutin',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            for (final entry
                in ((state['vote_result'] as Map)['counts'] as Map).entries)
              Text('${name(entry.key)} : ${entry.value} voix'),
            Text('Votes blancs : ${(state['vote_result'] as Map)['blank']}'),
            Text(
              'Abstentions : ${(state['vote_result'] as Map)['abstentions']}',
            ),
            Text(switch ((state['vote_result'] as Map)['reason']) {
              'tie' => 'Égalité : aucune élimination.',
              'blank' => 'Le vote blanc arrive en tête : aucune élimination.',
              'abstention' => 'Aucun bulletin reçu : aucune élimination.',
              'idiot_grace' =>
                '${name((state['vote_result'] as Map)['graced'])} est gracié, mais perd son droit de vote.',
              'scapegoat' =>
                '${name((state['vote_result'] as Map)['eliminated'])}, le Bouc émissaire, est éliminé à cause de l’égalité.',
              _ =>
                '${name((state['vote_result'] as Map)['eliminated'])} est éliminé par le village.',
            }),
          ],
          if (daytime && widget.showDayChat) ...[
            const SizedBox(height: 16),
            const Text(
              'Discussion générale',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              state['chat_open'] == true
                  ? 'Discussion ouverte'
                  : 'Discussion fermée par le MDJ',
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                primary: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final message
                        in (state['day_messages'] as List? ?? []))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '${name(message['author'])} : ${message['text']}',
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (widget.isHost)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Autoriser le chat général'),
                value: state['chat_open'] == true,
                onChanged: widget.onChat,
              ),
            if (!widget.isHost &&
                widget.connected &&
                matching &&
                private?['alive'] == true &&
                state['chat_open'] == true) ...[
              TextField(
                controller: _message,
                maxLength: 300,
                decoration: const InputDecoration(
                  labelText: 'Message au village',
                ),
              ),
              TextButton(
                onPressed: () {
                  if (_message.text.trim().isNotEmpty) {
                    send('day.chat', text: _message.text);
                    _message.clear();
                  }
                },
                child: const Text('Envoyer au village'),
              ),
            ],
            if (!widget.isHost && matching && private?['alive'] == false)
              const Text(
                'Tu es éliminé : tu peux suivre le débat, sans écrire ni voter.',
              ),
          ],
          if (daytime && !widget.showDayChat && widget.isHost)
            Material(
              type: MaterialType.transparency,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Autoriser le chat général'),
                value: state['chat_open'] == true,
                onChanged: widget.onChat,
              ),
            ),
          if (widget.isHost) ...[
            if (phase == 'role_reveal' || phase == 'vote_result') ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _seconds,
                decoration: const InputDecoration(
                  labelText: 'Durée de chaque appel',
                ),
                items: [
                  for (final seconds in [60, 120, 180])
                    DropdownMenuItem(
                      value: seconds,
                      child: Text('$seconds secondes'),
                    ),
                ],
                onChanged: (value) => setState(() => _seconds = value!),
              ),
              FilledButton.icon(
                onPressed: () => widget.onStart(_seconds),
                icon: const Icon(Icons.nights_stay),
                label: Text(
                  phase == 'vote_result'
                      ? 'Commencer la nuit suivante'
                      : 'Endormir le village',
                ),
              ),
            ],
            if (phase == 'day') ...[
              DropdownButtonFormField<int>(
                initialValue: _voteSeconds,
                decoration: const InputDecoration(labelText: 'Durée du vote'),
                items: [
                  for (final seconds in [30, 60, 120, 180, 300])
                    DropdownMenuItem(
                      value: seconds,
                      child: Text('$seconds secondes'),
                    ),
                ],
                onChanged: (value) => setState(() => _voteSeconds = value!),
              ),
              FilledButton.icon(
                onPressed: widget.onVote == null
                    ? null
                    : () => widget.onVote!(_voteSeconds),
                icon: const Icon(Icons.how_to_vote),
                label: const Text('Ouvrir le vote du village'),
              ),
            ],
            if (timed) ...[
              OutlinedButton(
                onPressed: state['closed'] == true
                    ? null
                    : state['paused'] == true
                    ? widget.onResume
                    : widget.onPause,
                child: Text(
                  state['paused'] == true
                      ? 'Reprendre le chronomètre'
                      : 'Mettre en pause',
                ),
              ),
              if (phase == 'seer')
                Text(
                  'Consultations reçues : ${(host['visions'] as Map? ?? {}).length}',
                ),
              if (phase == 'wolves') ...[
                const Text('Choix privés de la meute :'),
                for (final entry
                    in (host['wolf_choices'] as Map? ?? {}).entries)
                  Text('${name(entry.key)} → ${name(entry.value)}'),
                for (final message in (host['wolf_messages'] as List? ?? []))
                  Text('${name(message['author'])} : ${message['text']}'),
              ],
              if (phase == 'witch')
                Text(
                  'Sorcière : ${(host['witch_done'] as List? ?? []).isEmpty ? 'en attente' : 'choix confirmés'} · Victime de la meute : ${name(host['victim'])}',
                ),
              if (phase == 'hunter')
                Text(
                  host['hunter_done'] == true
                      ? 'Tir effectué.'
                      : 'Tir en attente. À défaut de choix, poursuivre sans tir.',
                ),
              if (![
                'seer',
                'wolves',
                'witch',
                'hunter',
                'voting',
              ].contains(phase)) ...[
                Text(
                  'Actions confirmées : ${(host['ability_done'] as List? ?? []).where((value) => (value as String).startsWith('$phase:')).length}',
                ),
                if (phase == 'guardian')
                  Text('Protection : ${name(host['protected'])}'),
                if (phase == 'alpha')
                  Text('Seconde victime : ${name(host['extra_attack'])}'),
                if (phase == 'white_wolf')
                  Text('Cible du Loup Blanc : ${name(host['white_attack'])}'),
                if (phase == 'infection')
                  Text('Infection : ${name(host['infection_target'])}'),
              ],
            ],
            if (night) ...[
              const SizedBox(height: 12),
              const Text('Appels de la nuit · ordre choisi par le MDJ'),
              for (final action in (host['night_actions'] as List? ?? [])) ...[
                OutlinedButton(
                  onPressed:
                      action['available'] == true &&
                          widget.connected &&
                          widget.onCallNight != null
                      ? () => widget.onCallNight!(action['action'] as String)
                      : null,
                  child: Text(
                    '${action['label'] ?? switch (action['action']) {
                          'seer' => 'Appeler la Voyante',
                          'wolves' => 'Appeler les Loups-Garous',
                          'witch' => 'Appeler la Sorcière',
                          _ => 'Appeler ce rôle',
                        }}${action['completed'] == true ? ' · terminé' : ''}',
                  ),
                ),
                if (action['reason'] != null && action['completed'] != true)
                  Text(action['reason'] as String),
              ],
              if (phase == 'sleep')
                FilledButton(
                  onPressed: widget.connected && widget.onFinishNight != null
                      ? () async {
                          final unfinished =
                              (host['night_actions'] as List? ?? []).any(
                                (a) => a['completed'] != true,
                              );
                          if (unfinished) {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Terminer la nuit ?'),
                                content: const Text(
                                  'Certains rôles n’ont pas été appelés. Leurs actions ne seront pas exécutées cette nuit.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Retour'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Réveiller le village'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed != true || !mounted) return;
                          }
                          widget.onFinishNight?.call();
                        }
                      : null,
                  child: const Text('Réveiller le village'),
                )
              else
                FilledButton(
                  onPressed: state['paused'] == true ? null : advance,
                  child: const Text('Terminer cet appel'),
                ),
            ],
            if (!night &&
                !['role_reveal', 'day', 'vote_result', 'ended'].contains(phase))
              FilledButton(
                onPressed: state['paused'] == true ? null : advance,
                child: Text(nextLabel),
              ),
          ] else ...[
            if (matching) ...[
              if (private?['role_notice'] != null)
                Text(private!['role_notice'] as String),
              if (private?['camp_label'] != null)
                Text('Ton camp actuel : ${private!['camp_label']}'),
              if (private?['lover'] != null)
                Text(
                  'Ton amoureux : ${name(private!['lover'])}${private['mixed_lovers'] == true ? ' · Votre couple doit rester seul en vie.' : ''}',
                ),
              if (private?['charmed'] == true)
                Text(
                  'Tu es charmé. Autres joueurs charmés : ${(private!['charmed_ids'] as List? ?? []).map(name).join(', ')}',
                ),
              if (private?['peek_message'] != null)
                Text('Murmure capté : ${private!['peek_message']}'),
              if ((private?['spotted_girls'] as List? ?? []).isNotEmpty)
                Text(
                  'Repérée par la meute : ${(private!['spotted_girls'] as List).map(name).join(', ')}',
                ),
              if (private?['ability_submitted'] == true)
                const Text('Action confirmée pour cet appel.'),
              if (private?['vote_right'] == false &&
                  daytime &&
                  private?['alive'] == true)
                const Text(
                  'Tu peux discuter, mais tu ne disposes pas du droit de vote.',
                ),
            ],
            if (canAct && private?['ability'] is Map)
              abilityPanel(private!['ability'] as Map),
            if (!widget.connected)
              const Text('Reconnecte-toi pour retrouver tes actions.'),
            if (phase == 'voting' && matching) ...[
              if (private?['vote_submitted'] == true)
                Text(
                  private?['vote_target'] == null
                      ? 'Ton bulletin actuel : vote blanc.'
                      : 'Ton bulletin actuel : ${name(private?['vote_target'])}.',
                ),
              if (canVote) ...[
                DropdownButtonFormField<String>(
                  key: ValueKey('vote-${state['phase_revision']}'),
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Ton vote',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '_blank',
                      child: Text('Vote blanc'),
                    ),
                    for (final id in alive)
                      DropdownMenuItem(value: id, child: Text(name(id))),
                  ],
                  onChanged: (value) => setState(() => _voteChoice = value),
                ),
                FilledButton(
                  onPressed: _voteChoice == null
                      ? null
                      : () => send(
                          'vote.cast',
                          target: _voteChoice == '_blank' ? null : _voteChoice,
                        ),
                  child: Text(
                    private?['vote_submitted'] == true
                        ? 'Modifier mon vote'
                        : 'Confirmer mon vote',
                  ),
                ),
                const Text(
                  'Tu peux modifier ton bulletin jusqu’à la clôture. Ne pas voter compte comme une abstention.',
                ),
              ],
            ],
            if (matching && private?['vision'] is Map) ...[
              const SizedBox(height: 12),
              Text(() {
                final vision = private!['vision'] as Map;
                final value = vision['kind'] == 'camp'
                    ? switch (vision['value']) {
                        'wolves' => 'Loups-Garous',
                        'village' => 'Village',
                        _ => 'Solitaire',
                      }
                    : configuredRole(vision['value'] as String).name;
                return 'Vision privée : ${name(vision['target'])} — $value';
              }()),
            ],
            if (canAct && phase == 'seer' && private?['role'] == 'seer') ...[
              choose(
                'Qui observer ?',
                targets,
                _target,
                (id) => setState(() => _target = id),
              ),
              FilledButton(
                onPressed: _target == null
                    ? null
                    : () => send('seer.inspect', target: _target),
                child: const Text('Confirmer ma vision'),
              ),
            ],
            if (matching &&
                (private?['is_pack'] == true ||
                    private?['role'] == 'werewolf') &&
                phase == 'wolves' &&
                private?['alive'] == true) ...[
              const SizedBox(height: 12),
              const Text('Espace privé de la meute'),
              Text(
                'Meute : ${(private!['pack'] as List).map(name).join(', ')}',
              ),
              for (final entry in (private['choices'] as Map).entries)
                Text('${name(entry.key)} choisit ${name(entry.value)}'),
              if (canAct) ...[
                choose(
                  'Victime proposée',
                  targets
                      .where((id) => !(private['pack'] as List).contains(id))
                      .toList(),
                  _target,
                  (id) => setState(() => _target = id),
                ),
                FilledButton(
                  onPressed: _target == null
                      ? null
                      : () => send('wolves.choose', target: _target),
                  child: const Text('Confirmer ce choix'),
                ),
                const Text(
                  'Tous les loups vivants doivent confirmer la même cible.',
                ),
                for (final message in (private['messages'] as List))
                  Text('${name(message['author'])} : ${message['text']}'),
                TextField(
                  controller: _message,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Message à la meute',
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (_message.text.trim().isNotEmpty) {
                      send('wolves.chat', text: _message.text);
                      _message.clear();
                    }
                  },
                  child: const Text('Envoyer à la meute'),
                ),
              ],
            ],
            if (canAct && phase == 'witch' && private?['role'] == 'witch') ...[
              const SizedBox(height: 12),
              Text(
                private!['life_available'] == true
                    ? 'Victime des loups : ${name(private['victim'])}'
                    : 'Potion de vie consommée : la victime reste secrète.',
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Utiliser la potion de vie'),
                value: _save,
                onChanged:
                    private['life_available'] == true &&
                        private['victim'] != null
                    ? (value) => setState(() => _save = value)
                    : null,
              ),
              if (private['death_available'] == true)
                choose(
                  'Potion de mort (facultative)',
                  alive,
                  _kill,
                  (id) => setState(() => _kill = id),
                  optional: true,
                )
              else
                const Text('Potion de mort déjà consommée.'),
              FilledButton(
                onPressed: () =>
                    send('witch.potions', save: _save, kill: _kill),
                child: const Text('Confirmer mes potions ou passer'),
              ),
            ],
            if (canAct && phase == 'hunter') ...[
              choose(
                'Dernière cible',
                targets,
                _target,
                (id) => setState(() => _target = id),
              ),
              FilledButton(
                onPressed: _target == null
                    ? null
                    : () => send('hunter.shoot', target: _target),
                child: const Text('Confirmer mon dernier tir'),
              ),
            ],
            if (!canAct &&
                !['day', 'voting', 'vote_result', 'ended'].contains(phase))
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Patiente pendant cet appel. Le MDJ dirige la suite.',
                ),
              ),
          ],
        ],
      ),
    );
  }
}
