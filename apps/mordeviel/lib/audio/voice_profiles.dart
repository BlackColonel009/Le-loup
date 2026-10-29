// Catalogue du jeu. Ne pas régénérer avec l'ancien pipeline Windows/SAPI.
class VoiceProfile {
  const VoiceProfile(
    this.id,
    this.label,
    this.edition,
    this.description,
    this.prefix, {
    this.isApproved = false,
    this.availableCues,
  });
  final String id, label, edition, description, prefix;
  final bool isApproved;
  final Set<String>? availableCues;
  bool supports(String cue) =>
      isApproved && (availableCues == null || availableCues!.contains(cue));
  String assetFor(String cue) => '$prefix$cue';
}

const disabledVoiceProfile = VoiceProfile(
  'none',
  'Narration du maître du jeu',
  'Classique',
  'Aucune voix disponible.',
  '',
);

const voiceProfiles = <VoiceProfile>[
  VoiceProfile("classic_male", "Masculine", "Classique", "Narrateur français posé et clair.", "neural/classic_male/",
    isApproved: true,
    availableCues: {'death_idiot.wav', 'death_piper.wav', 'death_villager.wav', 'ended_piper.wav', 'mdj_alpha.wav', 'mdj_close_alpha.wav', 'mdj_close_cupid.wav', 'mdj_close_guardian.wav', 'mdj_close_infection.wav', 'mdj_close_metamorph.wav', 'mdj_close_piper.wav', 'mdj_close_seer.wav', 'mdj_close_sisters.wav', 'mdj_close_white_wolf.wav', 'mdj_close_witch.wav', 'mdj_close_wolves.wav', 'mdj_cupid.wav', 'mdj_dawn.wav', 'mdj_day.wav', 'mdj_guardian.wav', 'mdj_hunter.wav', 'mdj_infection.wav', 'mdj_mayor_election.wav', 'mdj_mayor_succession.wav', 'mdj_metamorph.wav', 'mdj_piper.wav', 'mdj_role_reveal.wav', 'mdj_scapegoat.wav', 'mdj_seer.wav', 'mdj_sisters.wav', 'mdj_sleep.wav', 'mdj_vote_result.wav', 'mdj_voting.wav', 'mdj_white_wolf.wav', 'mdj_witch.wav', 'mdj_wolves.wav', 'preview.wav', 'wolves.wav'},
  ),
  VoiceProfile("classic_female", "Féminine", "Classique", "Narratrice française claire et calme.", "neural/classic_female/",
    isApproved: true,
    availableCues: {'death_cupid.wav', 'death_little_girl.wav', 'death_seer.wav', 'death_sisters.wav', 'death_villager_female.wav', 'ended_lovers.wav', 'mdj_alpha.wav', 'mdj_close_alpha.wav', 'mdj_close_cupid.wav', 'mdj_close_guardian.wav', 'mdj_close_infection.wav', 'mdj_close_metamorph.wav', 'mdj_close_piper.wav', 'mdj_close_seer.wav', 'mdj_close_sisters.wav', 'mdj_close_white_wolf.wav', 'mdj_close_witch.wav', 'mdj_close_wolves.wav', 'mdj_cupid.wav', 'mdj_dawn.wav', 'mdj_day.wav', 'mdj_guardian.wav', 'mdj_hunter.wav', 'mdj_infection.wav', 'mdj_mayor_election.wav', 'mdj_mayor_succession.wav', 'mdj_metamorph.wav', 'mdj_piper.wav', 'mdj_role_reveal.wav', 'mdj_scapegoat.wav', 'mdj_seer.wav', 'mdj_sisters.wav', 'mdj_sleep.wav', 'mdj_vote_result.wav', 'mdj_voting.wav', 'mdj_white_wolf.wav', 'mdj_witch.wav', 'mdj_wolves.wav', 'preview.wav', 'wolves.wav'},
  ),
  VoiceProfile("intense_male", "Masculine grave", "Intense", "Grave, lente et chargée de suspense.", "neural/intense_male/",
    isApproved: true,
    availableCues: {'death_guardian.wav', 'death_hunter.wav', 'mdj_alpha.wav', 'mdj_close_alpha.wav', 'mdj_close_cupid.wav', 'mdj_close_guardian.wav', 'mdj_close_infection.wav', 'mdj_close_metamorph.wav', 'mdj_close_piper.wav', 'mdj_close_seer.wav', 'mdj_close_sisters.wav', 'mdj_close_white_wolf.wav', 'mdj_close_witch.wav', 'mdj_close_wolves.wav', 'mdj_cupid.wav', 'mdj_dawn.wav', 'mdj_day.wav', 'mdj_guardian.wav', 'mdj_hunter.wav', 'mdj_infection.wav', 'mdj_mayor_election.wav', 'mdj_mayor_succession.wav', 'mdj_metamorph.wav', 'mdj_piper.wav', 'mdj_role_reveal.wav', 'mdj_scapegoat.wav', 'mdj_seer.wav', 'mdj_sisters.wav', 'mdj_sleep.wav', 'mdj_vote_result.wav', 'mdj_voting.wav', 'mdj_white_wolf.wav', 'mdj_witch.wav', 'mdj_wolves.wav', 'preview.wav', 'wolves.wav'},
  ),
  VoiceProfile("intense_female", "Féminine grave", "Intense", "Voix sombre et résonante.", "neural/intense_female/",
    isApproved: true,
    availableCues: {'mdj_alpha.wav', 'mdj_close_alpha.wav', 'mdj_close_cupid.wav', 'mdj_close_guardian.wav', 'mdj_close_infection.wav', 'mdj_close_metamorph.wav', 'mdj_close_piper.wav', 'mdj_close_seer.wav', 'mdj_close_sisters.wav', 'mdj_close_white_wolf.wav', 'mdj_close_witch.wav', 'mdj_close_wolves.wav', 'mdj_cupid.wav', 'mdj_dawn.wav', 'mdj_day.wav', 'mdj_guardian.wav', 'mdj_hunter.wav', 'mdj_infection.wav', 'mdj_mayor_election.wav', 'mdj_mayor_succession.wav', 'mdj_metamorph.wav', 'mdj_piper.wav', 'mdj_role_reveal.wav', 'mdj_scapegoat.wav', 'mdj_seer.wav', 'mdj_sisters.wav', 'mdj_sleep.wav', 'mdj_vote_result.wav', 'mdj_voting.wav', 'mdj_white_wolf.wav', 'mdj_witch.wav', 'mdj_wolves.wav', 'preview.wav', 'wolves.wav'},
  ),
  VoiceProfile("duke", "Le Duc", "Intense", "Ton solennel et annonces de cour.", "neural/duke/",
    isApproved: true,
    availableCues: {'death_scapegoat.wav', 'ended_draw.wav', 'ended_village.wav', 'mdj_alpha.wav', 'mdj_close_alpha.wav', 'mdj_close_cupid.wav', 'mdj_close_guardian.wav', 'mdj_close_infection.wav', 'mdj_close_metamorph.wav', 'mdj_close_piper.wav', 'mdj_close_seer.wav', 'mdj_close_sisters.wav', 'mdj_close_white_wolf.wav', 'mdj_close_witch.wav', 'mdj_close_wolves.wav', 'mdj_cupid.wav', 'mdj_dawn.wav', 'mdj_day.wav', 'mdj_guardian.wav', 'mdj_hunter.wav', 'mdj_infection.wav', 'mdj_mayor_election.wav', 'mdj_mayor_succession.wav', 'mdj_metamorph.wav', 'mdj_piper.wav', 'mdj_role_reveal.wav', 'mdj_scapegoat.wav', 'mdj_seer.wav', 'mdj_sisters.wav', 'mdj_sleep.wav', 'mdj_vote_result.wav', 'mdj_voting.wav', 'mdj_white_wolf.wav', 'mdj_witch.wav', 'mdj_wolves.wav', 'preview.wav', 'wolves.wav'},
  ),
  VoiceProfile("old_wizard", "Vieux sorcier", "Horreur", "Voix vieillie, tremblante et voilée.", "neural/old_wizard/",
    isApproved: true,
    availableCues: {'death_elder.wav', 'death_wolf_father.wav', 'elder_curse.wav', 'mdj_alpha.wav', 'mdj_close_alpha.wav', 'mdj_close_cupid.wav', 'mdj_close_guardian.wav', 'mdj_close_infection.wav', 'mdj_close_metamorph.wav', 'mdj_close_piper.wav', 'mdj_close_seer.wav', 'mdj_close_sisters.wav', 'mdj_close_white_wolf.wav', 'mdj_close_witch.wav', 'mdj_close_wolves.wav', 'mdj_cupid.wav', 'mdj_dawn.wav', 'mdj_day.wav', 'mdj_guardian.wav', 'mdj_hunter.wav', 'mdj_infection.wav', 'mdj_mayor_election.wav', 'mdj_mayor_succession.wav', 'mdj_metamorph.wav', 'mdj_piper.wav', 'mdj_role_reveal.wav', 'mdj_scapegoat.wav', 'mdj_seer.wav', 'mdj_sisters.wav', 'mdj_sleep.wav', 'mdj_vote_result.wav', 'mdj_voting.wav', 'mdj_white_wolf.wav', 'mdj_witch.wav', 'mdj_wolves.wav', 'preview.wav', 'wolves.wav'},
  ),
  VoiceProfile("old_witch", "Vieille sorcière", "Horreur", "Timbre voilé et tremblement discret.", "neural/old_witch/",
    isApproved: true,
    availableCues: {'death_witch.wav', 'horror_laugh.wav', 'mdj_alpha.wav', 'mdj_close_alpha.wav', 'mdj_close_cupid.wav', 'mdj_close_guardian.wav', 'mdj_close_infection.wav', 'mdj_close_metamorph.wav', 'mdj_close_piper.wav', 'mdj_close_seer.wav', 'mdj_close_sisters.wav', 'mdj_close_white_wolf.wav', 'mdj_close_witch.wav', 'mdj_close_wolves.wav', 'mdj_cupid.wav', 'mdj_dawn.wav', 'mdj_day.wav', 'mdj_guardian.wav', 'mdj_hunter.wav', 'mdj_infection.wav', 'mdj_mayor_election.wav', 'mdj_mayor_succession.wav', 'mdj_metamorph.wav', 'mdj_piper.wav', 'mdj_role_reveal.wav', 'mdj_scapegoat.wav', 'mdj_seer.wav', 'mdj_sisters.wav', 'mdj_sleep.wav', 'mdj_vote_result.wav', 'mdj_voting.wav', 'mdj_white_wolf.wav', 'mdj_witch.wav', 'mdj_wolves.wav', 'preview.wav', 'revival.wav', 'witch_potion.wav', 'wolves.wav'},
  ),
  VoiceProfile("werewolf", "Loup-garou", "Horreur", "Grondement grave sous une parole intelligible.", "neural/werewolf/",
    isApproved: true,
    availableCues: {'death_alpha_wolf.wav', 'death_werewolf.wav', 'death_white_wolf.wav', 'ended_white_wolf.wav', 'ended_wolves.wav', 'mdj_alpha.wav', 'mdj_close_alpha.wav', 'mdj_close_cupid.wav', 'mdj_close_guardian.wav', 'mdj_close_infection.wav', 'mdj_close_metamorph.wav', 'mdj_close_piper.wav', 'mdj_close_seer.wav', 'mdj_close_sisters.wav', 'mdj_close_white_wolf.wav', 'mdj_close_witch.wav', 'mdj_close_wolves.wav', 'mdj_cupid.wav', 'mdj_dawn.wav', 'mdj_day.wav', 'mdj_guardian.wav', 'mdj_hunter.wav', 'mdj_infection.wav', 'mdj_mayor_election.wav', 'mdj_mayor_succession.wav', 'mdj_metamorph.wav', 'mdj_piper.wav', 'mdj_role_reveal.wav', 'mdj_scapegoat.wav', 'mdj_seer.wav', 'mdj_sisters.wav', 'mdj_sleep.wav', 'mdj_vote_result.wav', 'mdj_voting.wav', 'mdj_white_wolf.wav', 'mdj_witch.wav', 'mdj_wolves.wav', 'preview.wav', 'role_reveal.wav', 'wolves.wav'},
  ),
  VoiceProfile("ghost", "Fantôme", "Horreur", "Voix aérienne et échos lointains.", "neural/ghost/",
    isApproved: true,
    availableCues: {'death_angel.wav', 'ended_angel.wav', 'mdj_alpha.wav', 'mdj_close_alpha.wav', 'mdj_close_cupid.wav', 'mdj_close_guardian.wav', 'mdj_close_infection.wav', 'mdj_close_metamorph.wav', 'mdj_close_piper.wav', 'mdj_close_seer.wav', 'mdj_close_sisters.wav', 'mdj_close_white_wolf.wav', 'mdj_close_witch.wav', 'mdj_close_wolves.wav', 'mdj_cupid.wav', 'mdj_dawn.wav', 'mdj_day.wav', 'mdj_guardian.wav', 'mdj_hunter.wav', 'mdj_infection.wav', 'mdj_mayor_election.wav', 'mdj_mayor_succession.wav', 'mdj_metamorph.wav', 'mdj_piper.wav', 'mdj_role_reveal.wav', 'mdj_scapegoat.wav', 'mdj_seer.wav', 'mdj_sisters.wav', 'mdj_sleep.wav', 'mdj_vote_result.wav', 'mdj_voting.wav', 'mdj_white_wolf.wav', 'mdj_witch.wav', 'mdj_wolves.wav', 'preview.wav', 'wolves.wav'},
  ),
  VoiceProfile("cold_killer", "Tueur de sang-froid", "Horreur", "Voix sèche, lente et retenue.", "neural/cold_killer/",
    isApproved: true,
    availableCues: {'death_metamorph.wav', 'mdj_alpha.wav', 'mdj_close_alpha.wav', 'mdj_close_cupid.wav', 'mdj_close_guardian.wav', 'mdj_close_infection.wav', 'mdj_close_metamorph.wav', 'mdj_close_piper.wav', 'mdj_close_seer.wav', 'mdj_close_sisters.wav', 'mdj_close_white_wolf.wav', 'mdj_close_witch.wav', 'mdj_close_wolves.wav', 'mdj_cupid.wav', 'mdj_dawn.wav', 'mdj_day.wav', 'mdj_guardian.wav', 'mdj_hunter.wav', 'mdj_infection.wav', 'mdj_mayor_election.wav', 'mdj_mayor_succession.wav', 'mdj_metamorph.wav', 'mdj_piper.wav', 'mdj_role_reveal.wav', 'mdj_scapegoat.wav', 'mdj_seer.wav', 'mdj_sisters.wav', 'mdj_sleep.wav', 'mdj_vote_result.wav', 'mdj_voting.wav', 'mdj_white_wolf.wav', 'mdj_witch.wav', 'mdj_wolves.wav', 'preview.wav', 'wolves.wav'},
  ),
];
VoiceProfile voiceProfileById(String? id) => voiceProfiles.firstWhere(
  (p) => p.id == id, orElse: () => voiceProfiles.first,
);
