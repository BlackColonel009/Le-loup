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
  'elder': (profile: 'old_wizard', cue: 'death_elder.wav'),
  'hunter': (profile: 'intense_male', cue: 'death_hunter.wav'),
  'witch': (profile: 'old_witch', cue: 'death_witch.wav'),
  'werewolf': (profile: 'werewolf', cue: 'death_werewolf.wav'),
  'seer': (profile: 'classic_female', cue: 'death_seer.wav'),
};
