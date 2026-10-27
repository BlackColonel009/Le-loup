part 'classic_role_catalog.g.dart';

class ClassicRole {
  const ClassicRole(
    this.id,
    this.name,
    this.camp,
    this.phase,
    this.summary,
    this.details, {
    this.implemented = true,
    this.assetExtension = 'jpg',
    this.feminine = false,
  });

  final String id;
  final String name;
  final String camp;
  final String phase;
  final String summary;
  final String details;
  final bool implemented;
  final String assetExtension;
  final bool feminine;
  String get asset => id == 'villager' && feminine
      ? 'assets/cards/villager_female.png'
      : 'assets/cards/$id.$assetExtension';
}

const coreClassicRoles = [
  ClassicRole(
    'villager',
    'Villageois',
    'Village',
    'Jour',
    'Sans pouvoir nocturne, débattez et votez pour démasquer les loups.',
    'Votre force repose sur l’observation, les échanges et le vote. '
        'En règles classiques, aucun pouvoir ne bloque spécialement votre parole.',
  ),
  ClassicRole(
    'werewolf',
    'Loup-Garou',
    'Loups-Garous',
    'Nuit',
    'Chaque nuit, choisissez une victime avec la meute. Sans accord unanime, personne n’est dévoré.',
    'Tous les loups vivants doivent confirmer la même cible avant la fin du temps imparti. '
        'Un désaccord ou une réponse manquante annule l’attaque. Le MDJ peut suspendre le temps en cas de coupure.',
  ),
  ClassicRole(
    'seer',
    'Voyante',
    'Village',
    'Nuit',
    'Chaque nuit, découvrez le rôle exact d’un autre joueur.',
    'Le MDJ choisit l’ordre des appels nocturnes. Le résultat est connu uniquement de vous et du MDJ. '
        'Le réglage « camp uniquement », s’il est choisi, doit être annoncé au Codex avant la partie.',
  ),
  ClassicRole(
    'witch',
    'Sorcière',
    'Village',
    'Nuit',
    'Vous possédez deux potions, chacune utilisable une fois : Vie — sauvez la victime des loups, '
        'même vous-même. Mort — éliminez un joueur. Vous pouvez utiliser les deux la même nuit.',
    'Vous agissez après la résolution de la chasse et ne voyez la victime principale que tant que votre potion de vie est disponible. '
        'Chaque potion est utilisable une seule fois dans la partie. La potion de vie empêche la mort : elle ne ressuscite pas un joueur déjà éliminé. '
        'Vous pouvez vous sauver et utiliser les deux potions la même nuit. La potion de vie annule aussi une infection visant cette victime.',
  ),
  ClassicRole(
    'hunter',
    'Chasseur',
    'Village',
    'À votre mort',
    'À votre mort, quelle qu’en soit la cause, éliminez un autre joueur encore vivant.',
    'Si vous mourez la nuit, le tir est résolu au réveil, après l’annonce des morts. '
        'Au vote du jour, vous tirez avant la nuit suivante. La victoire est vérifiée après les réactions. '
        'Votre cible doit être encore vivante. Vous ne tirez pas si votre pouvoir a été perdu à cause de l’Ancien.',
  ),
];

const playableClassicRoles = [...coreClassicRoles, ...additionalClassicRoles];
const classicRoles = playableClassicRoles;

ClassicRole configuredRole(
  String id, {
  bool seerCampOnly = false,
  bool feminine = false,
}) {
  final role = classicRoles.firstWhere((role) => role.id == id);
  if (id == 'villager' && feminine) {
    return ClassicRole(
      role.id,
      'Villageoise',
      role.camp,
      role.phase,
      role.summary,
      role.details,
      feminine: true,
    );
  }
  if (id != 'seer' || !seerCampOnly) return role;
  return ClassicRole(
    role.id,
    role.name,
    role.camp,
    role.phase,
    'Chaque nuit, découvrez le camp d’un autre joueur.',
    'Variante choisie par le MDJ : seul le camp est révélé, pas le rôle exact. '
        'Le recto présente la règle classique ; ce réglage la remplace pour cette partie. '
        'Le MDJ choisit l’ordre des appels. Le résultat reste privé à vous et au MDJ.',
  );
}
