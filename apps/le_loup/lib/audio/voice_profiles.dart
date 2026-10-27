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
  VoiceProfile(
    "classic_male",
    "Masculine",
    "Classique",
    "Narrateur français posé et clair.",
    "neural/classic_male/",
    isApproved: true,
    availableCues: {'preview.wav', 'wolves.wav'},
  ),
  VoiceProfile(
    "classic_female",
    "Féminine",
    "Classique",
    "Narratrice française claire et calme.",
    "neural/classic_female/",
    isApproved: true,
    availableCues: {'preview.wav', 'wolves.wav'},
  ),
  VoiceProfile(
    "intense_male",
    "Masculine grave",
    "Intense",
    "Grave, lente et chargée de suspense.",
    "neural/intense_male/",
    isApproved: true,
    availableCues: {'preview.wav', 'wolves.wav'},
  ),
  VoiceProfile(
    "intense_female",
    "Féminine grave",
    "Intense",
    "Voix sombre et résonante.",
    "neural/intense_female/",
    isApproved: true,
    availableCues: {'preview.wav', 'wolves.wav'},
  ),
  VoiceProfile(
    "duke",
    "Le Duc",
    "Intense",
    "Ton solennel et annonces de cour.",
    "neural/duke/",
    isApproved: true,
    availableCues: {'preview.wav', 'wolves.wav'},
  ),
  VoiceProfile(
    "old_wizard",
    "Vieux sorcier",
    "Horreur",
    "Voix vieillie, tremblante et voilée.",
    "neural/old_wizard/",
    isApproved: true,
    availableCues: {'preview.wav', 'wolves.wav'},
  ),
  VoiceProfile(
    "old_witch",
    "Vieille sorcière",
    "Horreur",
    "Timbre voilé et tremblement discret.",
    "neural/old_witch/",
    isApproved: true,
    availableCues: {'preview.wav', 'witch_potion.wav', 'wolves.wav'},
  ),
  VoiceProfile(
    "werewolf",
    "Loup-garou",
    "Horreur",
    "Grondement grave sous une parole intelligible.",
    "neural/werewolf/",
    isApproved: true,
    availableCues: {'preview.wav', 'role_reveal.wav', 'wolves.wav'},
  ),
  VoiceProfile(
    "ghost",
    "Fantôme",
    "Horreur",
    "Voix aérienne et échos lointains.",
    "neural/ghost/",
    isApproved: true,
    availableCues: {'preview.wav', 'wolves.wav'},
  ),
  VoiceProfile(
    "cold_killer",
    "Tueur de sang-froid",
    "Horreur",
    "Voix sèche, lente et retenue.",
    "neural/cold_killer/",
    isApproved: true,
    availableCues: {'preview.wav', 'wolves.wav'},
  ),
];
VoiceProfile voiceProfileById(String? id) => voiceProfiles.firstWhere(
  (p) => p.id == id,
  orElse: () => voiceProfiles.first,
);
