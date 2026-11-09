import 'dart:math';
import 'chat_stickers.g.dart';
import 'player_mentions.dart';

enum BotTemperament { prudent, theatrical, playful, direct }

class BotPersona {
  const BotPersona(
    this.name,
    this.gender, {
    this.temperament = BotTemperament.prudent,
  });
  final String name, gender;
  final BotTemperament temperament;
  bool get feminine => gender == 'female';
  static BotPersona forIndex(int index) {
    const names = [
      'Léa',
      'Hugo',
      'Nora',
      'Malik',
      'Inès',
      'Oscar',
      'Jade',
      'Émile',
      'Awa',
      'Noé',
      'Maya',
      'Adam',
      'Rose',
      'Léo',
      'Sara',
      'Jules',
      'Emma',
      'Yanis',
      'Lina',
      'Louis',
    ];
    return BotPersona(
      'Bot ${names[(index - 1) % names.length]} $index',
      index.isOdd ? 'female' : 'male',
      temperament:
          BotTemperament.values[(index - 1) % BotTemperament.values.length],
    );
  }
}

/// Editable first dialogue catalogue. No string claims knowledge of secret roles.
const botReplies = <String, List<String>>{
  'accuse': [
    'Je pense que tu pourrais être le loup. Tu nous expliques ton raisonnement ?',
    'Ton attitude m’intrigue. Pourquoi devrais-je te faire confiance ?',
    'Je garde un œil sur toi pour ce vote. Tu suspectes qui ?',
  ],
  'silent': [
    'Tu es resté discret aujourd’hui. Tu as une piste à partager ?',
    'On ne t’a pas encore beaucoup entendu. Que penses-tu du vote ?',
  ],
  'me': [
    'Oui, toi ! Tu es louche. 😏',
    'Oui, je te parle ! Convaincs-moi que je me trompe.',
    'Toi, oui. Mais je t’écoute avant de décider.',
  ],
  'why': [
    'C’est un soupçon, pas une preuve. Tu peux défendre ton choix ?',
    'Je compare les prises de parole et les votes. Et toi, quel est ton argument ?',
    'Je préfère poser la question que suivre le village les yeux fermés.',
  ],
  'counter': [
    'Si j’étais un loup, je choisirais peut-être mieux mes accusations… 😏',
    'Qu’est-ce qui te fait dire cela ?',
    'Ah bon ? Explique ton accusation, je t’écoute.',
    'Je suis {sure} de mon raisonnement, mais je peux encore changer d’avis.',
  ],
  'deny': [
    'Je note ta défense. Donne-nous plutôt un argument concret.',
    'Tout le monde peut dire ça ! Qui te semble suspect ?',
    'Je ne suis pas encore {convaincu}. Explique-moi ton vote.',
  ],
  'greeting': [
    'Salut ! Je suis {pret} pour le conseil. Tu suspectes qui ?',
    'Je t’écoute. On essaie de démêler les pistes ensemble ?',
  ],
  'thanks': ['Avec plaisir ! Gardons les yeux ouverts. 🐺'],
  'fallback': [
    'Je t’écoute, mais précise ton idée : tu accuses qui et pourquoi ?',
    'Intéressant… tu peux expliquer ce qui te fait penser ça ?',
    'Je suis {curieux} de connaître ton raisonnement.',
  ],
};

const _temperamentReplies = <BotTemperament, Map<String, List<String>>>{
  BotTemperament.prudent: {
    'accuse': [
      'Je préfère rester prudente, mais tes votes m’interpellent.',
      'J’ai un doute sur toi, sans preuve formelle. Tu peux nous éclairer ?',
      'Je compare les prises de parole avant de me décider.',
    ],
    'silent': [
      'Tu es resté discret aujourd’hui. As-tu une piste à partager ?',
      'Je ne veux pas tirer de conclusion trop vite, mais on t’a peu entendu.',
    ],
    'why': [
      'C’est une impression, pas une certitude. Qu’en penses-tu ?',
      'Je peux me tromper. Quel élément te semble le plus important ?',
    ],
    'counter': [
      'Je prends note de ta défense. Qu’est-ce qui t’a fait penser cela ?',
      'Tu as peut-être raison de me questionner. Regardons les faits.',
    ],
    'deny': [
      'Je t’entends. Essayons de comparer nos arguments calmement.',
      'D’accord, je garde ça en tête. Qui te paraît le plus suspect ?',
    ],
    'fallback': [
      'Je reste {curieux} : quel détail te fait penser cela ?',
      'Je préfère vérifier avant de voter. Tu peux préciser ?',
    ],
  },
  BotTemperament.theatrical: {
    'accuse': [
      'Un étrange pressentiment plane autour de tes votes… que nous caches-tu ?',
      'Le village retient son souffle : ton attitude mérite des explications.',
      'Les ombres s’allongent, et tes silences aussi. Qu’as-tu à dire ?',
    ],
    'silent': [
      'Le silence pèse lourd au conseil… veux-tu enfin livrer ta piste ?',
      'Même les hiboux t’ont davantage entendu que nous aujourd’hui !',
    ],
    'why': [
      'Le doute est une brume, pas une preuve. Aide-nous à y voir clair.',
      'Chaque vote laisse une trace. Quelle est la tienne ?',
    ],
    'counter': [
      'Belle accusation ! Mais le conseil n’a pas encore rendu son verdict.',
      'Tu retournes la scène contre moi ? Défends donc ton intuition !',
    ],
    'deny': [
      'Ta défense est entendue. Le village attend maintenant des indices.',
      'Les mots sont posés. Qui désignes-tu à ton tour ?',
    ],
    'greeting': [
      'Le conseil est ouvert ! Qui fera trembler le village ce soir ?',
      'Habitants, les langues se délient… quelle est ta piste ?',
    ],
    'fallback': [
      'Une nouvelle piste se dessine… peux-tu nous en dire davantage ?',
      'Le village t’écoute. Quel mystère veux-tu éclaircir ?',
    ],
  },
  BotTemperament.playful: {
    'accuse': [
      'Je ne t’accuse pas… je pose juste une question très insistante 😏',
      'Tes votes ont un petit goût de mystère. Tu nous racontes ?',
      'Je garde un œil sur toi — enfin, deux, par précaution !',
    ],
    'silent': [
      'Tu joues à cache-cache avec le conseil ? On t’écoute !',
      'Même mon chat a donné son avis avant toi. Alors, ta piste ?',
    ],
    'why': [
      'Bonne question ! Mon indice tient dans tes votes… tu en penses quoi ?',
      'Parce que mon instinct de village s’agite. Et le tien ?',
    ],
    'counter': [
      'Moi, un loup ? Voilà une drôle de chasse aux suspects !',
      'Tu me soupçonnes ? Je vais devoir soigner ma défense alors 😄',
    ],
    'deny': [
      'Noté ! Mais il va falloir plus qu’un « c’est pas moi » 😉',
      'Je te crois… à moitié. Qui d’autre a l’air louche ?',
    ],
    'greeting': [
      'Salut ! On démêle les soupçons avant que le village s’endorme ?',
      'Coucou ! Alors, qui a les oreilles qui frémissent aujourd’hui ?',
    ],
    'thanks': ['Avec plaisir ! Gardons l’œil ouvert 😄'],
    'fallback': [
      'Je t’écoute ! Donne-moi un nom et un indice, et on enquête.',
      'Hmm… développe, détective. Qu’est-ce qui t’a mis la puce à l’oreille ?',
    ],
  },
  BotTemperament.direct: {
    'accuse': [
      'Je pense que tu pourrais être un loup. Explique tes votes.',
      'Tu es mon principal suspect pour l’instant. Que réponds-tu ?',
      'Je voterais contre toi. Quel est ton argument ?',
    ],
    'silent': [
      'Tu as peu parlé. Donne-nous ta piste avant le vote.',
      'Tu n’as pas encore défendu ton choix. Pourquoi ?',
    ],
    'why': [
      'Tes votes ne sont pas cohérents avec tes explications. Tu réponds ?',
      'Je n’ai pas de preuve. Dis-moi pourquoi tu as voté ainsi.',
    ],
    'counter': [
      'Tu peux me soupçonner. Quel fait te fait conclure ça ?',
      'D’accord, défends ton accusation avec un élément concret.',
    ],
    'deny': [
      'Dire que tu es innocent ne suffit pas. Qui suspectes-tu ?',
      'J’ai entendu. Maintenant, donne un argument vérifiable.',
    ],
    'greeting': [
      'Le conseil commence. Qui est ton suspect et pourquoi ?',
      'Allons droit au but : que révèlent les votes ?',
    ],
    'fallback': [
      'Précise ta pensée : qui suspectes-tu, et sur quel indice ?',
      'Je t’écoute. Donne un nom et explique ton raisonnement.',
    ],
  },
};

String normalizeBotText(String text) {
  var value = text.toLowerCase().replaceAll('’', "'");
  const accents = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'ô': 'o',
    'ö': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
  };
  accents.forEach((from, to) {
    value = value.replaceAll(from, to);
  });
  return value;
}

String botIntent(String text) {
  final t = normalizeBotText(text);
  bool has(String pattern) => RegExp(pattern).hasMatch(t);
  if (has(r'\b(toi|tu|t.es)\b.{0,35}\bloup\b|\bloup\b.{0,20}\b(toi|tu)\b'))
    return 'counter';
  if (has(r'\b(pourquoi|preuve|preuves|explique|comment)\b')) return 'why';
  if (has(r'\b(pas moi|innocent|innocente|pas le loup)\b')) return 'deny';
  if (has(r'\bmoi\b')) return 'me';
  if (has(r'\b(salut|bonjour|bonsoir|coucou)\b')) return 'greeting';
  if (has(r'\bmerci\b')) return 'thanks';
  return 'fallback';
}

class BotConversation {
  BotConversation(this.persona, {Random? random})
    : _random = random ?? Random();
  final BotPersona persona;
  final Random _random;
  final _seen = <String>{}, _announced = <String>{};
  final _lastLines = <String, String>{};
  final _turns = <String, int>{};
  DateTime? _last;
  int _night = -1, _messages = 0;
  String line(String intent) {
    final options =
        _temperamentReplies[persona.temperament]?[intent] ??
        botReplies[intent]!;
    final choices = options.where((s) => s != _lastLines[intent]).toList();
    final text =
        (choices.isEmpty ? options : choices)[_random.nextInt(
          (choices.isEmpty ? options : choices).length,
        )];
    _lastLines[intent] = text;
    return text
        .replaceAll('{sure}', persona.feminine ? 'sûre' : 'sûr')
        .replaceAll(
          '{convaincu}',
          persona.feminine ? 'convaincue' : 'convaincu',
        )
        .replaceAll('{pret}', persona.feminine ? 'prête' : 'prêt')
        .replaceAll('{curieux}', persona.feminine ? 'curieuse' : 'curieux');
  }

  bool _announce(String key) {
    if (!_announced.add(key)) return false;
    if (_announced.length > 300) _announced.remove(_announced.first);
    return true;
  }

  int _stableIndex(String value, int length) {
    var hash = 0;
    for (final unit in value.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash % length;
  }

  String _reaction() {
    const ids = [
      'classic_villager_joy',
      'classic_idiot_confused',
      'classic_scapegoat_scared',
    ];
    final id = ids[_random.nextInt(ids.length)];
    final sticker = chatStickerById(id);
    if (sticker == null) {
      throw StateError('Sticker de réaction introuvable : $id.');
    }
    return stickerMessage(sticker);
  }

  Map<String, dynamic>? next(
    String id,
    Map game,
    Map own,
    DateTime now, {
    String? voteTarget,
  }) {
    if (game['paused'] == true ||
        game['closed'] == true ||
        game['chat_open'] != true ||
        own['alive'] != true ||
        own['phase_revision'] != game['phase_revision'] ||
        ![
          'day',
          'mayor_election',
          'voting',
          'vote_result',
        ].contains(game['phase']))
      return null;
    final messages = (game['day_messages'] as List? ?? [])
        .whereType<Map>()
        .toList();
    if (_night != game['night']) {
      _night = game['night'] as int? ?? 0;
      _messages = 0;
      _turns.clear();
    }
    if (_messages >= 12 ||
        (_last != null && now.difference(_last!).inMilliseconds < 3000))
      return null;
    final players = (game['players'] as List? ?? []).whereType<Map>().toList();
    final bots = players
        .where((p) => p['is_bot'] == true)
        .map((p) => p['id'])
        .toSet();
    final alive = (game['alive_ids'] as List? ?? []).toSet();
    final burst = messages.reversed
        .takeWhile((m) => bots.contains(m['author']))
        .length;
    String name(dynamic who) =>
        players.where((p) => p['id'] == who).firstOrNull?['nickname']
            as String? ??
        'Joueur';
    Map<String, dynamic> say(String text, {String? replyTo}) {
      _last = now;
      _messages++;
      return {
        'action': 'day.chat',
        'phase_revision': game['phase_revision'],
        'text': text.length > 300 ? text.substring(0, 300) : text,
        if (replyTo != null) 'reply_to': replyTo,
      };
    }

    for (final m in messages) {
      final key = '${m['id']}';
      if (_seen.contains(key)) continue;
      _seen.add(key);
      if (_seen.length > 300) _seen.remove(_seen.first);
      final author = m['author'];
      if (author == id || !alive.contains(author)) continue;
      final text = m['text'] as String? ?? '';
      final tagged =
          mentionedPlayers(text, players).contains(id) ||
          m['reply_author'] == id;
      if (!bots.contains(author) &&
          tagged &&
          (_turns['$author'] ?? 0) < 5 &&
          !text.startsWith('[[sticker:')) {
        _turns['$author'] = (_turns['$author'] ?? 0) + 1;
        return say(
          '@${name(author)} ${line(botIntent(text))}',
          replyTo: m['id'] as String?,
        );
      }
      // One rotating peer reacts to addressed bot messages; stickers cannot
      // trigger another reaction.
      if (burst < 3 &&
          bots.contains(author) &&
          text.contains('@') &&
          !text.startsWith('[[sticker:')) {
        final reactors =
            bots
                .where((bot) => bot != author && alive.contains(bot))
                .map((bot) => '$bot')
                .toList()
              ..sort();
        final messageId = m['id'] as String? ?? key;
        if (reactors.isNotEmpty &&
            reactors[_stableIndex(messageId, reactors.length)] == id &&
            _announce('react:$messageId')) {
          return say(_reaction(), replyTo: messageId);
        }
      }
    }
    if (burst < 3 &&
        game['phase'] == 'voting' &&
        voteTarget != null &&
        !bots.contains(voteTarget) &&
        alive.contains(voteTarget) &&
        _announce('vote:$_night')) {
      final silent = !messages.any((m) => m['author'] == voteTarget);
      // A silence allegation is only used when no public message exists.
      return say('@${name(voteTarget)} ${line(silent ? 'silent' : 'accuse')}');
    }
    return null;
  }
}
