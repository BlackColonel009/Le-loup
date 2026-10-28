class GameEnding {
  const GameEnding(
    this.title,
    this.subtitle,
    this.role,
    this.profile,
    this.cue,
  );
  final String title, subtitle, role, profile, cue;
}

const gameEndings = {
  'village': GameEnding(
    'Le village est sauvé !',
    'Honneur aux villageois.',
    'villager',
    'duke',
    'ended_village.wav',
  ),
  'wolves': GameEnding(
    'La meute règne…',
    'Les Loups-Garous remportent la partie.',
    'werewolf',
    'werewolf',
    'ended_wolves.wav',
  ),
  'white_wolf': GameEnding(
    'Honneur au Loup Blanc !',
    'Seul, il a défié tous les camps.',
    'white_wolf',
    'werewolf',
    'ended_white_wolf.wav',
  ),
  'piper': GameEnding(
    'Honneur au Joueur de Flûte !',
    'Le village a succombé à sa mélodie.',
    'piper',
    'classic_male',
    'ended_piper.wav',
  ),
  'angel': GameEnding(
    'L’Ange a mis fin au plaisir…',
    'Son destin s’est accompli.',
    'angel',
    'ghost',
    'ended_angel.wav',
  ),
  'lovers': GameEnding(
    'L’amour a défié tous les camps.',
    'Honneur aux amoureux !',
    'cupid',
    'classic_female',
    'ended_lovers.wav',
  ),
  'draw': GameEnding(
    'Le silence a gagné.',
    'Partie nulle. Merci à tous les joueurs.',
    'villager',
    'duke',
    'ended_draw.wav',
  ),
};

const deathSpeeches = {
  'villager': DeathSpeech(
    'classic_male',
    'death_villager.wav',
    'Je pars… ouvrez les yeux avant la prochaine nuit.',
  ),
  'werewolf': DeathSpeech(
    'werewolf',
    'death_werewolf.wav',
    'Vous m’avez trouvé… mais combien en reste-t-il ?',
  ),
  'seer': DeathSpeech(
    'classic_female',
    'death_seer.wav',
    'J’avais vu les ténèbres… personne ne m’a crue.',
  ),
  'witch': DeathSpeech(
    'old_witch',
    'death_witch.wav',
    'Mes potions sont mortes avec moi… débrouillez-vous !',
  ),
  'hunter': DeathSpeech(
    'intense_male',
    'death_hunter.wav',
    'Je tombe… mais mon fusil parle encore.',
  ),
  'little_girl': DeathSpeech(
    'classic_female',
    'death_little_girl.wav',
    'J’ai vu des ombres… elles sont encore parmi vous.',
  ),
  'metamorph': DeathSpeech(
    'cold_killer',
    'death_metamorph.wav',
    'Vous emportez mon visage… jamais mes secrets.',
  ),
  'cupid': DeathSpeech(
    'classic_female',
    'death_cupid.wav',
    'Mes flèches se taisent… que l’amour vous survive.',
  ),
  'guardian': DeathSpeech(
    'intense_male',
    'death_guardian.wav',
    'Ma garde s’achève… veillez les uns sur les autres.',
  ),
  'elder': DeathSpeech(
    'old_wizard',
    'death_elder.wav',
    'La mémoire du village… s’éteint avec moi.',
  ),
  'scapegoat': DeathSpeech(
    'duke',
    'death_scapegoat.wav',
    'Vous vouliez un coupable… vous perdez un innocent.',
  ),
  'alpha_wolf': DeathSpeech(
    'werewolf',
    'death_alpha_wolf.wav',
    'Vous abattez l’Alpha… la meute n’oubliera pas.',
  ),
  'white_wolf': DeathSpeech(
    'werewolf',
    'death_white_wolf.wav',
    'Ma chasse s’arrête… mon ombre restera.',
  ),
  'wolf_father': DeathSpeech(
    'old_wizard',
    'death_wolf_father.wav',
    'Vous tuez le père… mais son héritage demeure.',
  ),
  'idiot': DeathSpeech(
    'classic_male',
    'death_idiot.wav',
    'Vous riez de moi… rirez-vous encore demain ?',
  ),
  'piper': DeathSpeech(
    'classic_male',
    'death_piper.wav',
    'Ma dernière note s’envole… écoutez le silence.',
  ),
  'angel': DeathSpeech(
    'ghost',
    'death_angel.wav',
    'Mes ailes se referment… votre jugement demeure.',
  ),
};

class DeathSpeech {
  const DeathSpeech(this.profile, this.cue, this.text);
  final String profile, cue, text;
}

const villagerFemaleSpeech = DeathSpeech(
  'classic_female',
  'death_villager_female.wav',
  'Je pars… ouvrez les yeux avant la prochaine nuit.',
);
const elderCurseSpeech = DeathSpeech(
  'old_wizard',
  'elder_curse.wav',
  'Que le ciel vous pardonne… et vous prive de vos pouvoirs.',
);
DeathSpeech? deathSpeechFor(
  String? publicRole, {
  bool feminine = false,
  bool cursed = false,
}) {
  if (cursed) return elderCurseSpeech;
  if (publicRole == 'villager' && feminine) return villagerFemaleSpeech;
  return deathSpeeches[publicRole];
}
