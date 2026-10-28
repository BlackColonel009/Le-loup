const variantRoleIds = {'seer', 'metamorph', 'guardian', 'werewolf'};
const cardEditions = {'classic', 'intense', 'horror'};

String cardEdition(
  Map<String, String> styles,
  String role,
  int copy,
  String fallback,
) => styles['$role#$copy'] ?? styles[role] ?? fallback;

const cardVariantRules = <String, Map<String, String>>{
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
        'Vous chassez normalement avec la meute. Une fois, pendant son éveil, sondez un vivant extérieur à la meute : vous apprenez s’il est protégé par un Salvateur ou par la résistance intacte de l’Ancien. Aucun rôle n’est révélé, aucune protection n’est retirée. Cette information est privée.',
  },
  'werewolf:horror': {
    'name': 'Dévoreur de secrets',
    'rules':
        'Vous chassez normalement. Une fois, demandez un voile sur la victime commune : si elle est réellement dévorée, son rôle reste caché jusqu’au réveil suivant. Une attaque empêchée ne consomme pas la charge. Une seule charge est consommée si plusieurs loups voilent la même victime. La fin de partie révèle tout. Le MDJ connaît toujours les rôles.',
  },
};

Map<String, String>? cardVariant(String role, String edition) =>
    cardVariantRules['$role:$edition'];
