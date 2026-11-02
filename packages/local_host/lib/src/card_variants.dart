const variantRoleIds = {
  'seer',
  'metamorph',
  'guardian',
  'werewolf',
  'villager',
  'witch',
  'hunter',
  'little_girl',
  'cupid',
  'elder',
  'scapegoat',
  'alpha_wolf',
  'white_wolf',
  'wolf_father',
  'idiot',
  'piper',
  'angel',
  'sisters',
};
const cardEditions = {'classic', 'intense', 'horror'};

String cardEdition(
  Map<String, String> styles,
  String role,
  int copy,
  String fallback,
) => styles['$role#$copy'] ?? styles[role] ?? fallback;

const cardVariantRules = <String, Map<String, String>>{
  'cupid:intense': {
    'name': 'Tisseur de liens',
    'rules':
        'Liez deux amoureux comme d’habitude. Pendant leur première rencontre nocturne, ils disposent d’un échange écrit privé de 60 secondes maximum, fermé et effacé quand le MDJ termine leur appel. Leurs morts restent liées. Aucun autre joueur ne reçoit cet échange.',
  },
  'cupid:horror': {
    'name': 'Cupidon des pactes',
    'rules':
        'Les morts des amoureux restent liées. Avant une chasse, ils peuvent rompre ce lien une fois, uniquement si tous deux donnent leur accord pendant leur appel. Ils perdent alors leurs deux bulletins de condamnation du jour suivant cette nuit. Un refus ou une réponse manquante conserve le lien et la charge.',
  },
  'sisters:intense': {
    'name': 'Sœurs complices',
    'rules':
        'Vous reconnaissez votre sœur au début. Une fois, avec son accord, ouvrez un échange écrit privé de 60 secondes maximum pendant votre appel nocturne. Il disparaît à la fermeture de l’appel. Ce pouvoir est commun aux deux sœurs : deux cartes Intense n’accordent pas deux échanges. Une infection ultérieure reste possible.',
  },
  'sisters:horror': {
    'name': 'Sœurs du serment',
    'rules':
        'Vous reconnaissez votre sœur. Une fois, avant la chasse, choisissez toutes les deux la même sœur à préserver : une attaque de la meute qui la vise sera transférée à l’autre cette nuit. La destinataire garde ses protections éventuelles. Le serment consomme la charge commune dès l’accord, même sans attaque ; il ne bloque ni poison, ni tir personnel, ni vote.',
  },
  'scapegoat:intense': {
    'name': 'Médiateur',
    'rules':
        'Une fois, lors d’une égalité qui vous sacrifierait, choisissez un second scrutin à la place. Vous ne votez pas dans ce second tour. Une nouvelle égalité entraîne votre sacrifice habituel ; aucun troisième scrutin n’est ajouté. Vous pouvez aussi accepter le sacrifice initial.',
  },
  'scapegoat:horror': {
    'name': 'Bouc maudit',
    'rules':
        'Si vous êtes éliminé par le vote, votre choix habituel des électeurs du lendemain reste disponible. Vous pouvez également marquer un survivant : il choisit de révéler publiquement son camp ou de perdre son prochain scrutin de condamnation. Sans réponse avant ce scrutin, il perd le vote et garde son camp secret.',
  },
  'mayor:intense': {
    'name': 'Maire stratège',
    'rules':
        'Votre titre est public et indépendant de votre rôle secret. Une fois, avant le dépouillement, renoncez à votre vote double pour imposer un second scrutin en cas d’égalité. Votre bulletin vaut alors une voix pendant les deux tours. Aucun troisième scrutin. À votre mort, désignez normalement votre successeur.',
  },
  'mayor:horror': {
    'name': 'Maire au testament scellé',
    'rules':
        'Votre titre est public et indépendant de votre rôle secret. Pendant la journée, préparez ou modifiez secrètement votre successeur. Votre testament devient public à votre mort, après les éventuelles réactions en chaîne. Si le successeur est mort, une nouvelle élection est proposée. Sans testament préparé, la succession habituelle s’applique.',
  },
  'little_girl:intense': {
    'name': 'Espionne',
    'rules':
        'Lors de votre tentative nocturne, écoutez jusqu’à deux murmures distincts au lieu d’un. Vous ne connaissez pas leurs auteurs. Le risque habituel de détection reste d’une chance sur trois. Vous n’obtenez aucun accès au vocal privé de la meute.',
  },
  'little_girl:horror': {
    'name': 'Petite Ombre',
    'rules':
        'Votre espionnage habituel reste disponible. Une fois, déposez un faux murmure écrit dans le canal des loups : il est clairement annoncé comme provenant d’une présence inconnue. Cette intrusion comporte une chance sur deux d’être repérée et ne révèle jamais automatiquement votre identité hors de ce risque.',
  },
  'elder:intense': {
    'name': 'Ancien protecteur',
    'rules':
        'Avant la chasse, transmettez votre résistance encore intacte à un autre vivant. Elle arrêtera sa première attaque de la meute ; vous perdez alors la vôtre. La résistance ne bloque ni poison, ni vote, ni tir personnel. Votre malédiction classique reste applicable.',
  },
  'elder:horror': {
    'name': 'Ancien des présages',
    'rules':
        'Une fois, avant la chasse, annoncez publiquement une prédiction sur une victime de la meute pour cette nuit. Si une attaque de la meute devait la tuer, elle est sauvée et vous perdez votre résistance personnelle. Une protection préalable qui bloque déjà l’attaque ne valide pas le présage. Votre malédiction classique reste applicable.',
  },
  'idiot:intense': {
    'name': 'Fou lucide',
    'rules':
        'Votre première condamnation est graciée et vous perdez votre vote habituel. Après cette grâce, vous disposez d’un unique bulletin exceptionnel : activez-le pendant le scrutin d’une journée de votre choix. Il n’autorise aucun nouveau vote lors d’une journée ultérieure.',
  },
  'idiot:horror': {
    'name': 'Fou contagieux',
    'rules':
        'Lors de votre première grâce, vous pouvez désigner publiquement un autre vivant sur l’écran du résultat. Ce joueur perd son bulletin de condamnation uniquement pendant la journée suivante. Vous perdez votre vote habituel pour toute la partie et conservez votre parole.',
  },
  'piper:intense': {
    'name': 'Virtuose',
    'rules':
        'Vos charmes habituels restent disponibles. Une fois par partie, charmez trois joueurs au lieu de deux pendant le même appel. Vous gagnez toujours seulement lorsque tous les autres survivants sont réellement charmés.',
  },
  'piper:horror': {
    'name': 'Musicien des illusions',
    'rules':
        'Une fois, ajoutez un faux charmé à la liste privée présentée aux vrais charmés. Le leurre ne reçoit pas de charme et ne compte jamais pour votre victoire. Vous connaissez la vraie liste et conservez votre action de charme habituelle pendant cet appel.',
  },
  'angel:intense': {
    'name': 'Ange vigilant',
    'rules':
        'Gagnez si le village vous élimine au premier scrutin de condamnation. En cas d’échec, vous devenez l’Éclaireur Intense avec une observation unique, au lieu d’un Villageois sans pouvoir. Une égalité rejouée constitue toujours le même scrutin.',
  },
  'angel:horror': {
    'name': 'Ange du sursis',
    'rules':
        'Gagnez si le village vous élimine au premier ou au deuxième scrutin de condamnation. Pendant cette épreuve, aucune protection nocturne ne peut vous sauver, y compris la potion de vie. Après un échec au deuxième vote, vous devenez un Villageois classique sans pouvoir. Une égalité rejouée ne consomme pas une nouvelle journée d’épreuve.',
  },
  'alpha_wolf:intense': {
    'name': 'Alpha tenace',
    'rules':
        'Votre seconde attaque habituelle reste disponible tant que la meute est intacte. Après la première mort dans la meute, vous conservez une ultime seconde attaque, utilisable une fois. Elle reste distincte de la chasse collective et vise une autre cible hors meute.',
  },
  'alpha_wolf:horror': {
    'name': 'Alpha de la terreur',
    'rules':
        'Une fois, remplacez votre seconde attaque par la terreur : la cible survit à cette capacité, mais perd son bulletin lors du scrutin de condamnation suivant, y compris un éventuel second scrutin. Elle conserve sa parole. Cette option exige que votre seconde attaque soit encore disponible.',
  },
  'white_wolf:intense': {
    'name': 'Solitaire patient',
    'rules':
        'Vous conservez votre objectif de dernier survivant et votre attaque personnelle une nuit sur deux. Une fois, reportez cette attaque à la nuit suivante. Vous ne tirez pas pendant la nuit du report et ne recevez aucune attaque supplémentaire. Un appel reporté non joué est perdu.',
  },
  'white_wolf:horror': {
    'name': 'Dépeceur',
    'rules':
        'Une fois, lors de votre appel personnel, remplacez votre attaque contre un loup par une attaque contre un vivant extérieur à la meute. Les loups sont prévenus qu’un traître chasse parmi eux, sans connaître votre identité. Aucun tir supplémentaire.',
  },
  'wolf_father:intense': {
    'name': 'Meneur',
    'rules':
        'Votre unique infection remplace la mort de la victime commune. Choisissez la conversion à la résolution de cette nuit ou au début de la suivante. La potion de vie et la protection contre la meute peuvent toujours empêcher l’infection. Une conversion ne permet jamais de rejouer un appel déjà effectué.',
  },
  'wolf_father:horror': {
    'name': 'Père des ombres',
    'rules':
        'Votre unique infection peut rester dormante jusqu’au début de la deuxième nuit suivante. Vous pouvez l’activer pendant la nuit intermédiaire en répondant à votre appel. La cible reste dans son camp et ignore la dormance jusqu’à sa conversion. Si elle meurt avant, la charge est perdue. Potion de vie et protection peuvent empêcher la contamination initiale.',
  },
  'villager:intense': {
    'name': 'Éclaireur',
    'rules':
        'Une fois par partie, observez une autre maison. Au matin, vous apprenez si au moins un pouvoir nocturne l’a visée, sans connaître l’auteur ou l’action. Votre propre observation ne compte pas. Une chasse collective compte pour une action.',
  },
  'villager:horror': {
    'name': 'Veilleur marqué',
    'rules':
        'Une fois, observez une autre maison. Au matin, découvrez si aucune, une ou plusieurs actions nocturnes l’ont visée, sans auteur ni nature des pouvoirs. Votre propre observation ne compte pas. Votre maison porte une marque publique pendant la journée suivante.',
  },
  'witch:intense': {
    'name': 'Alchimiste',
    'rules':
        'Vous gardez une seule potion de vie et une seule potion de mort. Votre poison peut agir immédiatement ou au réveil suivant. Le poison différé consomme votre potion de mort dès confirmation ; vous pouvez ensuite confirmer votre potion de vie pendant le même appel. Aucune potion supplémentaire.',
  },
  'witch:horror': {
    'name': 'Sorcière des malédictions',
    'rules':
        'À la place du poison immédiat, condamnez une cible au prochain crépuscule. Elle est prévenue. Si le village exécute un membre de la meute durant cette journée, la condamnation est annulée. Votre unique potion de mort est consommée dès confirmation ; la potion de vie reste utilisable pendant cet appel.',
  },
  'hunter:intense': {
    'name': 'Franc-tireur',
    'rules':
        'À votre mort, choisissez votre tir habituel OU renoncez au tir pour transmettre à un survivant un bouclier qui arrêtera une attaque de la meute, puis disparaîtra. Il ne bloque ni poison, ni tir personnel du Loup Blanc, ni vote, ni chagrin.',
  },
  'hunter:horror': {
    'name': 'Chasseur de monstres',
    'rules':
        'Votre dernier tir reste disponible quelle que soit votre mort. Si ce premier tir élimine un membre actuel de la meute, vous pouvez tirer une seconde fois. Deux victimes maximum ; le deuxième tir ne déclenche jamais de troisième tir.',
  },
  'seer:intense': {
    'name': 'Arbitre des âmes',
    'rules':
        'Chaque nuit, choisissez votre vision habituelle OU comparez deux autres vivants. La comparaison indique seulement si leurs camps sont identiques (Village, Loups ou Solitaires). Deux solitaires ne sont pas forcément alliés.',
  },
  'seer:horror': {
    'name': 'Oracle interdit',
    'rules':
        'Votre vision habituelle reste disponible. Une fois par partie, remplacez-la par deux visions la même nuit. Chaque cible apprend qu’elle a été sondée, sans connaître votre identité. Le réglage rôle exact/camp uniquement s’applique aux deux visions.',
  },
  'metamorph:intense': {
    'name': 'Marchand de visages',
    'rules':
        'La première nuit, consultez les camps de deux vivants, puis échangez ces deux cartes ou renoncez. La consultation consomme votre unique utilisation, même sans échange. L’édition et les pouvoirs déjà consommés suivent la carte.',
  },
  'metamorph:horror': {
    'name': 'Voleur d’âmes',
    'rules':
        'Échangez deux cartes une fois, à la nuit de votre choix, avant les autres appels. Vous pouvez attendre une autre nuit. Les cibles sont informées de leur nouvelle carte. L’édition et les charges restantes suivent la carte ; infection, charmes et amour restent liés au joueur.',
  },
  'guardian:intense': {
    'name': 'Gardien royal',
    'rules':
        'Votre protection normale reste disponible. Une fois, choisissez une protection renforcée qui arrête aussi le poison, mais pas le tir personnel du Loup Blanc. Vous ne pouvez pas vous viser avec ce renforcement, ni protéger la même cible deux nuits consécutives.',
  },
  'guardian:horror': {
    'name': 'Gardien sacrificiel',
    'rules':
        'Votre protection normale reste disponible. Une fois, choisissez un sacrifice à la place : si votre cible doit mourir d’une attaque nocturne directe (meute, Alpha, Loup Blanc ou poison), elle survit et vous mourez à sa place. Ni vote, ni tir du Chasseur, ni chagrin ne sont arrêtés. Le sacrifice ne bloque pas une infection. Pas d’auto-sacrifice ni de même cible deux nuits consécutives.',
  },
  'werewolf:intense': {
    'name': 'Traqueur',
    'rules':
        'Vous chassez normalement avec la meute. Une fois, pendant son éveil, sondez un vivant extérieur à la meute : vous apprenez si une protection nocturne contre la meute est actuellement active (Salvateur, résistance de l’Ancien, bouclier transmis, présage ou serment des Sœurs). Aucun rôle n’est révélé, aucune protection n’est retirée. Cette information est privée.',
  },
  'werewolf:horror': {
    'name': 'Dévoreur de secrets',
    'rules':
        'Vous chassez normalement. Une fois, demandez un voile sur la victime commune : si elle est réellement dévorée, son rôle reste caché jusqu’au réveil suivant. Une attaque empêchée ne consomme pas la charge. Une seule charge est consommée si plusieurs loups voilent la même victime. La fin de partie révèle tout. Le MDJ connaît toujours les rôles.',
  },
};

const _variantSummaries = <String, String>{
  'villager:intense':
      'Une fois, apprenez si un pouvoir a visé une autre maison pendant la nuit.',
  'villager:horror':
      'Une fois, comptez les actions visant une maison ; la vôtre sera marquée au matin.',
  'werewolf:intense':
      'Une fois, flairez une protection sans révéler de rôle. Votre chasse reste disponible.',
  'werewolf:horror':
      'Une fois, voilez le rôle d’une victime réellement dévorée jusqu’au réveil suivant.',
  'seer:intense':
      'Chaque nuit, choisissez une vision ou comparez les camps de deux vivants.',
  'seer:horror':
      'Une fois, obtenez deux visions. Les cibles sont averties sans connaître votre identité.',
  'witch:intense':
      'Votre poison unique peut agir immédiatement ou au réveil suivant.',
  'witch:horror':
      'Condamnez une cible au prochain crépuscule, sauf si le village exécute un loup.',
  'hunter:intense':
      'À votre mort, tirez ou transmettez un bouclier contre une attaque de la meute.',
  'hunter:horror':
      'Si votre tir de dernier souffle abat un loup, tirez encore. Deux victimes maximum.',
  'little_girl:intense':
      'Écoutez deux murmures anonymes. Le risque habituel d’être repérée demeure.',
  'little_girl:horror':
      'Une fois, trompez les loups avec un faux murmure. Risque de détection accru.',
  'metamorph:intense':
      'Consultez deux camps avant de décider d’échanger les cartes. Une seule utilisation.',
  'metamorph:horror':
      'Choisissez la nuit de votre échange unique, avant les autres appels.',
  'cupid:intense':
      'Liez deux amoureux et offrez-leur une première rencontre privée de 60 secondes.',
  'cupid:horror':
      'Les amoureux peuvent rompre leur pacte ensemble, en perdant leurs prochains votes.',
  'guardian:intense':
      'Une fois, votre protection arrête aussi le poison. Aucun auto-renforcement.',
  'guardian:horror':
      'Une fois, offrez votre vie pour empêcher une mort nocturne directe de votre cible.',
  'elder:intense':
      'Transmettez votre résistance intacte à un vivant ; vous perdez alors la vôtre.',
  'elder:horror':
      'Prédisez une victime. Si votre présage la sauve, perdez votre résistance.',
  'scapegoat:intense':
      'Une fois, remplacez votre sacrifice par un second scrutin, auquel vous ne votez pas.',
  'scapegoat:horror':
      'À votre exécution, imposez à un survivant de révéler son camp ou de perdre un vote.',
  'alpha_wolf:intense':
      'Après la première perte dans la meute, gardez une ultime seconde attaque.',
  'alpha_wolf:horror':
      'Une fois, remplacez votre seconde attaque par la perte du prochain vote d’une cible.',
  'white_wolf:intense':
      'Une fois, reportez votre attaque personnelle à la nuit suivante, sans attaque ajoutée.',
  'white_wolf:horror':
      'Une fois, chassez hors de la meute. Les loups apprendront qu’un traître chasse.',
  'wolf_father:intense':
      'Choisissez une conversion à la résolution nocturne ou au début de la nuit suivante.',
  'wolf_father:horror':
      'Gardez une infection dormante jusqu’à deux nuits et choisissez une activation anticipée.',
  'idiot:intense':
      'Après votre grâce, conservez un unique bulletin à jouer au scrutin de votre choix.',
  'idiot:horror':
      'Lors de votre grâce, privez publiquement un autre joueur du scrutin du lendemain.',
  'piper:intense':
      'Une fois, charmez trois joueurs au lieu de deux. Votre objectif reste identique.',
  'piper:horror':
      'Une fois, trompez les charmés avec un leurre qui ne compte jamais pour votre victoire.',
  'angel:intense':
      'Après un échec au premier vote, devenez l’Éclaireur Intense.',
  'angel:horror':
      'Visez le premier ou le deuxième vote, sans aucune protection nocturne pendant l’épreuve.',
  'sisters:intense':
      'Avec votre sœur, acceptez un échange privé de 60 secondes, une fois pour le duo.',
  'sisters:horror':
      'D’un commun accord, transférez une attaque de la meute d’une sœur vers l’autre.',
  'mayor:intense':
      'Une fois, échangez votre vote double contre un second scrutin en cas d’égalité.',
  'mayor:horror':
      'Scellez votre successeur en secret. Votre testament sera dévoilé à votre mort.',
};

Map<String, String>? cardVariant(String role, String edition) {
  final key = '$role:$edition';
  final rules = cardVariantRules[key];
  return rules == null
      ? null
      : {...rules, 'summary': _variantSummaries[key] ?? rules['rules']!};
}
