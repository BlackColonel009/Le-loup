enum VillageDestination { village, council, chat, actions, preparation }

/// Uses only public room state and this participant's authorized private data.
class VillageChannel {
  const VillageChannel({
    required this.kind,
    required this.title,
    required this.description,
    required this.scope,
    required this.messages,
    required this.writable,
    this.private = false,
  });
  final String kind, title, description, scope;
  final List messages;
  final bool writable, private;
  bool get available => kind != 'closed';

  static VillageChannel resolve(
    Map room,
    Map? own, {
    required bool isHost,
    required bool connected,
    int? bondRemaining,
  }) {
    final phase = room['phase'], game = room['game'] as Map? ?? const {};
    final active =
        connected && game['paused'] != true && game['closed'] != true;
    final alive = own?['alive'] == true;
    if (['day', 'mayor_election', 'voting', 'vote_result'].contains(phase)) {
      return VillageChannel(
        kind: 'day',
        title: 'Discussion générale',
        scope: 'day:${game['night'] ?? 0}',
        description: game['paused'] == true
            ? 'Partie en pause · lecture des échanges.'
            : game['chat_open'] == true
            ? 'Tout le village · le MDJ dirige le débat et le vote.'
            : 'Le MDJ a fermé la parole · les messages restent lisibles.',
        messages: game['day_messages'] as List? ?? const [],
        writable: active && !isHost && alive && game['chat_open'] == true,
      );
    }
    final bond = own?['bond_chat'] as Map?;
    final remaining = bondRemaining ?? bond?['remaining_ms'] as int? ?? 0;
    if (!isHost &&
        alive &&
        bond != null &&
        bond['kind'] == phase &&
        remaining > 0) {
      return VillageChannel(
        kind: bond['kind'] as String,
        private: true,
        title: bond['kind'] == 'lovers'
            ? 'Échange des amoureux'
            : 'Échange des Sœurs',
        description:
            'Entre vous · ${(remaining / 1000).ceil()} s restantes · effacé à la fermeture.',
        scope: '${bond['kind']}:${game['phase_revision'] ?? 0}',
        messages: bond['messages'] as List? ?? const [],
        writable: active && bond['open'] == true,
      );
    }
    final pack =
        phase == 'wolves' &&
        (isHost ||
            alive && (own?['is_pack'] == true || own?['role'] == 'werewolf'));
    if (pack) {
      return VillageChannel(
        kind: 'wolves',
        private: true,
        title: 'Discussion de la meute',
        description: 'Meute et MDJ · échanges effacés après cet appel.',
        scope: 'wolves:${game['night'] ?? game['phase_revision'] ?? 0}',
        messages: isHost
            ? (((room['game_host'] as Map?)?['wolf_messages'] as List?) ??
                  const [])
            : ((own?['messages'] as List?) ?? const []),
        writable: active && !isHost && own?['can_act'] == true,
      );
    }
    return const VillageChannel(
      kind: 'closed',
      title: 'Discussion fermée',
      description:
          'Le chat s’ouvrira au prochain appel autorisé. Le conseil est disponible le jour.',
      scope: 'closed',
      messages: [],
      writable: false,
    );
  }
}

class VillageGuidance {
  const VillageGuidance(
    this.title,
    this.detail,
    this.button,
    this.destination, {
    this.attention = false,
    this.confirmed = false,
    this.card = false,
  });
  final String title, detail, button;
  final VillageDestination destination;
  final bool attention, confirmed, card;

  static VillageGuidance resolve(
    Map room,
    Map? own, {
    required bool isHost,
    required bool connected,
    required VillageChannel channel,
    String? selfId,
  }) {
    final phase = room['phase'], game = room['game'] as Map? ?? const {};
    if (!connected) {
      return const VillageGuidance(
        'Connexion interrompue',
        'Tes choix sont conservés. Retrouve la reconnexion dans Actions.',
        'Revenir aux actions',
        VillageDestination.actions,
      );
    }
    if (game['paused'] == true) {
      return const VillageGuidance(
        'La partie est en pause',
        'Tu peux consulter le village et les échanges autorisés.',
        'Voir le village',
        VillageDestination.village,
      );
    }
    if (phase == 'lobby') {
      return VillageGuidance(
        isHost ? 'Rassemble ton village' : 'Prépare-toi pour la partie',
        'Retrouve les habitants, la composition et le bouton Prêt dans Préparation.',
        'Ouvrir la préparation',
        VillageDestination.preparation,
      );
    }
    if (phase == 'role_reveal' && !isHost && own?['role'] != null) {
      return const VillageGuidance(
        'Découvre ta carte secrète',
        'Ouvre-la à l’abri des regards, puis attends les appels du MDJ.',
        'Voir ma carte',
        VillageDestination.village,
        attention: true,
        card: true,
      );
    }
    if (phase == 'ended') {
      return const VillageGuidance(
        'La partie est terminée',
        'Retrouve le résultat et le récit des manches dans Actions.',
        'Voir le bilan',
        VillageDestination.actions,
      );
    }
    if (!isHost && own?['can_vote'] == true && own?['vote_submitted'] != true) {
      return VillageGuidance(
        phase == 'mayor_election'
            ? 'Ton bulletin pour le Maire est attendu'
            : 'C’est le moment de voter',
        'Rejoins Réunion et vote. Tu peux choisir un suspect ou voter blanc.',
        'Voter maintenant',
        VillageDestination.council,
        attention: true,
      );
    }
    if (!isHost && own?['can_act'] == true) {
      final chosen = own?['confirmed_selection'] as Map?;
      final packChosen =
          channel.kind == 'wolves' &&
          ((own?['choices'] as Map?)?.containsKey(selfId ?? own?['id']) ??
              false);
      final done =
          packChosen ||
          own?['ability_submitted'] == true ||
          own?['submitted'] == true;
      final reaction = [
        'hunter',
        'scapegoat',
        'mayor_succession',
        'mediation',
      ].contains(phase);
      if (!done || reaction && own?['hunter_done'] != true) {
        if (channel.kind == 'wolves' && !packChosen) {
          return const VillageGuidance(
            'La meute est réveillée',
            'Échange avec la meute dans le chat. Confirme ensuite ta cible dans Actions.',
            'Ouvrir la meute',
            VillageDestination.chat,
            attention: true,
          );
        }
        final optional =
            ['day', 'vote_result', 'voting'].contains(phase) ||
            chosen != null && own?['ability'] == null;
        return VillageGuidance(
          optional ? 'Un pouvoir est disponible' : 'À toi de jouer',
          'Les cibles et le bouton de confirmation se trouvent dans Actions.',
          'Ouvrir mon action',
          VillageDestination.actions,
          attention: true,
        );
      }
    }
    if (!isHost &&
        own?['vote_submitted'] == true &&
        ['voting', 'mayor_election'].contains(phase)) {
      return const VillageGuidance(
        'Ton bulletin est confirmé',
        'Tu peux le modifier jusqu’à la clôture dans Réunion et vote.',
        'Revoir mon vote',
        VillageDestination.council,
        confirmed: true,
      );
    }
    if (channel.private) {
      return VillageGuidance(
        channel.kind == 'wolves'
            ? 'Le chat de la meute est ouvert'
            : 'Ton échange privé est ouvert',
        channel.description,
        'Rejoindre le chat',
        VillageDestination.chat,
        confirmed: true,
      );
    }
    if (!isHost && own?['confirmed_selection'] != null) {
      return const VillageGuidance(
        'Choix confirmé',
        'Tu peux observer le village en attendant la suite.',
        'Voir le village',
        VillageDestination.village,
        confirmed: true,
      );
    }
    if (isHost) {
      return VillageGuidance(
        'Tu diriges la partie',
        'Les appels, le chronomètre et le passage à la phase suivante sont dans la Table du MDJ.',
        'Ouvrir la table du MDJ',
        VillageDestination.actions,
      );
    }
    if (['day', 'mayor_election', 'voting', 'vote_result'].contains(phase)) {
      return const VillageGuidance(
        'Le village se retrouve au conseil',
        'Discussion pour échanger · Réunion et vote pour les bulletins.',
        'Rejoindre le conseil',
        VillageDestination.council,
      );
    }
    return const VillageGuidance(
      'Le village s’endort',
      'Attends ton appel. Tu seras guidé ici dès qu’un choix sera disponible.',
      'Observer le village',
      VillageDestination.village,
    );
  }
}
