import 'package:flutter/material.dart';
import '../cards/classic_role.dart';
import 'narrative_journal.dart';

Future<void> showGameHistory(BuildContext context, Map game, List players) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => GameHistoryScreen(game: game, players: players),
      ),
    );

class GameHistoryScreen extends StatelessWidget {
  const GameHistoryScreen({
    super.key,
    required this.game,
    required this.players,
  });
  final Map game;
  final List players;
  String name(dynamic id) =>
      players
          .where((p) => p['id'] == id)
          .map((p) => p['nickname'] as String)
          .firstOrNull ??
      'Personne';
  String names(dynamic ids) => (ids as List? ?? []).map(name).join(', ');
  String role(dynamic id) => id is String ? configuredRole(id).name : 'Joueur';

  String describe(Map e) {
    final actor = e['kind'] == 'action' && e['role'] is String
        ? '${name(e['actor'])} (${configuredRole(e['role'] as String, edition: e['edition'] as String? ?? 'classic').name})'
        : name(e['actor']);
    final target = name(e['target']);
    final selected = names(e['targets']);
    switch (e['kind']) {
      case 'phase':
        return e['label'] as String;
      case 'sentence':
        return '$target : sentence « ${e['label']} ».';
      case 'death':
        return '$target (${role(e['role'])}) est éliminé : ${switch (e['cause']) {
          'night' => 'attaque de la meute',
          'poison' => 'potion de mort',
          'sacrifice' => 'sacrifice du Gardien',
          'hunter' => 'tir du Chasseur',
          'love' => 'mort de chagrin',
          'white_wolf' => 'attaque du Loup Blanc',
          _ => 'vote du village',
        }}.';
      case 'effect':
        return switch (e['effect']) {
          'infection' => '$target rejoint la meute.',
          'angel_becomes_villager' =>
            '$target devient ${e['edition'] == 'intense' ? 'Éclaireur Intense' : 'Simple Villageois'} après son épreuve.',
          'infection_pending' =>
            '$target porte une infection en attente de conversion.',
          'watch_result' =>
            '$actor a observé $target : ${switch (e['count']) {
              0 => 'aucune action',
              1 => 'une action',
              _ => 'plusieurs actions',
            }}.',
          'hunter_ward' =>
            'Le bouclier transmis par le Franc-tireur arrête une attaque sur $target.',
          'curse_lifted' =>
            'L’exécution d’un loup lève la malédiction visant $target.',
          'inherited_resistance' =>
            'La résistance transmise par l’Ancien sauve $target.',
          'presage_saved' =>
            'Le présage de $actor sauve $target et lui coûte sa résistance.',
          'sister_redirect' =>
            'Le serment transfère l’attaque de $target vers ${name(e['recipient'])}.',
          'elder_curse' =>
            'La malédiction de l’Ancien désactive les pouvoirs du Village.',
          'elder_resists' =>
            '$target résiste à sa première attaque de la meute.',
          'protected' =>
            'La protection du Salvateur bloque l’attaque sur $target.',
          'poison_blocked' =>
            'La protection renforcée bloque le poison visant $target.',
          'guardian_sacrifice' => '$actor offre sa vie pour sauver $target.',
          'role_veiled' =>
            'Le rôle de $target est voilé jusqu’au réveil suivant.',
          'saved' =>
            'La potion de vie sauve $target et annule son éventuelle infection.',
          'no_pack_victim' =>
            'Sans accord unanime, la meute n’élimine personne.',
          _ => 'Un effet de jeu est résolu pour $target.',
        };
      case 'mayor_election':
        return e['target'] == null
            ? 'Élection du Maire : aucun candidat départagé.'
            : '${name(e['target'])} est élu Maire. Bulletins : ${(e['ballots'] as Map).entries.map((b) => '${name(b.key)} → ${b.value == null ? 'blanc' : name(b.value)}').join(', ')}.';
      case 'mayor_succession':
        return e['sealed'] == true && e['valid'] == false
            ? 'Le successeur du testament de ${name(e['actor'])} est mort : une nouvelle élection est proposée.'
            : '${name(e['actor'])} transmet le titre de Maire à ${name(e['target'])}${e['sealed'] == true ? ' par testament scellé' : ''}.';
      case 'vote_round':
        return 'Premier scrutin à égalité : ${e['reason'] == 'mayor_revote' ? 'le Maire impose un second scrutin' : 'le Médiateur doit choisir entre relancer le scrutin et son sacrifice'}. Bulletins : ${(e['ballots'] as Map? ?? {}).entries.map((b) => '${name(b.key)} → ${b.value == null ? 'blanc' : name(b.value)}').join(', ')}.';
      case 'vote_result':
        final details = <String>[
          for (final b in (e['ballots'] as Map? ?? {}).entries)
            '${name(b.key)} → ${b.value == null ? 'vote blanc' : name(b.value)}',
          if ((e['abstained'] as List? ?? []).isNotEmpty)
            'Abstentions : ${names(e['abstained'])}',
          'Résultat : ${switch (e['reason']) {
            'tie' => 'égalité, aucune élimination',
            'blank' => 'le vote blanc l’emporte',
            'abstention' => 'aucun bulletin reçu',
            'scapegoat' => 'égalité : le Bouc émissaire est désigné',
            'idiot_grace' => '${name(e['graced'])} est gracié et perd son vote',
            _ => '${name(e['eliminated'])} est désigné',
          }}.',
          '${e['cast']} bulletin(s) / ${e['eligible']} votant(s) · ${e['blank']} vote(s) blanc(s).',
        ];
        return details.join('\n');
    }
    return switch (e['action']) {
      'vote.cast' =>
        '$actor → ${e['target'] == null ? 'vote blanc' : target} (bulletin confirmé).',
      'wolves.choose' => '$actor propose $target à la meute.',
      'wolves.scent' =>
        '$actor flaire $selected : ${e['result']?['protected'] == true ? 'protection détectée' : 'aucune protection détectée'}.',
      'wolves.veil' => '$actor demande de voiler la victime commune.',
      'seer.compare' =>
        '$actor compare $selected : ${e['result']?['same_camp'] == true ? 'même camp' : 'camps différents'}.',
      'seer.double' =>
        '$actor utilise ses deux visions interdites sur $selected.',
      'metamorph.peek' =>
        '$actor consulte les camps de $selected avant son échange.',
      'guardian.ward' =>
        '$actor renforce la protection de $selected contre le poison.',
      'guardian.sacrifice' =>
        '$actor accepte de mourir à la place de $selected en cas de mort nocturne directe.',
      'seer.inspect' =>
        '$actor observe $target : ${e['vision']?['kind'] == 'camp' ? switch (e['vision']?['value']) {
                'wolves' => 'Loups-Garous',
                'village' => 'Village',
                _ => 'Solitaire',
              } : role(e['vision']?['value'])}.',
      'witch.potions' =>
        '$actor : ${e['save'] == true ? 'potion de vie sur ${name(e['victim'])}' : 'aucune potion de vie'} ; ${e['kill'] != null ? 'potion de mort sur ${name(e['kill'])}' : 'aucune potion de mort'}.',
      'hunter.shoot' => '$actor tire sur $target.',
      'hunter.ward' =>
        '$actor renonce au tir et transmet un bouclier à $selected.',
      'villager.watch' =>
        '$actor observe la maison de $selected pour cette nuit.',
      'witch.delay' => '$actor utilise son poison différé sur $selected.',
      'witch.curse' =>
        '$actor condamne $selected au prochain crépuscule, sauf exécution d’un loup.',
      'alpha.terror' =>
        '$actor remplace son attaque supplémentaire par la terreur sur $selected.',
      'white_wolf.defer' =>
        '$actor reporte son attaque personnelle à la nuit suivante.',
      'white_wolf.outsider' =>
        '$actor chasse $selected hors de la meute et annonce la présence d’un traître.',
      'infection.immediate' =>
        '$actor choisit une conversion de $selected à la résolution de cette nuit.',
      'infection.dormant' =>
        '$actor laisse une infection dormante chez $selected.',
      'infection.activate' =>
        '$actor active son infection dormante chez $selected.',
      'idiot.ballot' => '$actor engage son unique bulletin exceptionnel.',
      'idiot.contagion' =>
        '$actor prive publiquement $selected du prochain scrutin.',
      'piper.triple' => '$actor utilise son triple charme sur $selected.',
      'piper.illusion' =>
        '$actor ajoute $selected comme faux charmé, sans effet sur sa victoire.',
      'little_girl.false_whisper' =>
        '$actor dépose un faux murmure anonyme dans la meute.',
      'elder.transfer' => '$actor transmet sa résistance intacte à $selected.',
      'elder.presage' =>
        '$actor prédit publiquement une attaque sur $selected.',
      'scapegoat.revote' =>
        '$actor relance le scrutin et renonce à son bulletin de ce tour.',
      'scapegoat.accept' => '$actor accepte son sacrifice pour l’égalité.',
      'scapegoat.mark' =>
        '$actor demande à $selected de révéler son camp ou de perdre son prochain vote.',
      'mark.reveal' => '$actor choisit de révéler publiquement son camp.',
      'mark.refuse' =>
        '$actor garde son camp secret et perd son prochain vote.',
      'mayor.strategy' =>
        '$actor renonce au vote double pour un éventuel second scrutin.',
      'mayor.testament' =>
        '$actor scelle son testament en faveur de $selected.',
      'lovers.break_agree' => '$actor accepte la rupture du pacte amoureux.',
      'lovers.break_decline' => '$actor refuse de rompre le pacte amoureux.',
      'sisters.chat_agree' => '$actor accepte la rencontre privée des Sœurs.',
      'sisters.chat_decline' => '$actor refuse la rencontre privée des Sœurs.',
      'sisters.transfer_agree' =>
        '$actor désigne $selected comme sœur dont l’attaque sera transférée.',
      'metamorph.swap' =>
        '$actor échange les cartes de $selected.${e['new_roles'] is Map ? ' Nouveaux rôles : ${(e['new_roles'] as Map).entries.map((r) => '${name(r.key)} : ${role(r.value)}').join(', ')}.' : ''}',
      'cupid.link' => '$actor lie les amoureux : $selected.',
      'guardian.protect' => '$actor protège $selected.',
      'alpha.choose' => '$actor choisit une seconde victime : $selected.',
      'white_wolf.choose' => '$actor attaque $selected.',
      'infection.convert' => '$actor tente d’infecter $selected.',
      'piper.charm' => '$actor charme $selected.',
      'scapegoat.voters' =>
        '$actor autorise à voter le lendemain : ${selected.isEmpty ? 'personne' : selected}.',
      'little_girl.peek' =>
        '$actor espionne la meute : ${e['spotted'] == true ? 'repérée' : 'non repérée'}.',
      'night.pass' => '$actor passe son action.',
      _ => '$actor confirme une action.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final ended = game['phase'] == 'ended';
    final events = ended ? game['history'] as List? ?? [] : [];
    return Scaffold(
      appBar: AppBar(title: const Text('Historique de la partie')),
      body: !ended
          ? const Center(
              child: Text('Le bilan sera disponible à la fin de la partie.'),
            )
          : events.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucun historique détaillé disponible pour cette partie. Les nouvelles parties l’enregistreront après la mise à jour du serveur.',
                ),
              ),
            )
          : NarrativeJournal(events: events, describe: describe),
    );
  }
}
