String packLabel(String id) =>
    const {
      'victory-poses': 'Victoires · Poses des personnages',
      'stickers-classic': 'Stickers · Émotions du village',
      'stickers-rewards': 'Stickers · Curiosités à collectionner',
      'avatars-classic': 'Avatars · Visages classiques',
      'avatars-rewards': 'Profils · Médaillons de légende',
      'borders-rewards': 'Bordures · Cadres de légende',
      'horror-cards': 'Horreur · Cartes',
      'intense-cards': 'Intense · Cartes',
      'horror-village': 'Horreur · Village et sentences',
      'horror-devour': 'Horreur · Vidéos de dévoration',
      'horror-ambience': 'Horreur · Sons d’ambiance',
      'voice-intense-male': 'Voix · Homme intense',
      'voice-intense-female': 'Voix · Femme intense',
      'voice-duke': 'Voix · Duc',
      'voice-old-wizard': 'Voix · Vieux sorcier',
      'voice-old-witch': 'Voix · Vieille sorcière',
      'voice-werewolf': 'Voix · Loup-Garou',
      'voice-ghost': 'Voix · Fantôme',
      'voice-cold-killer': 'Voix · Tueur',
    }[id] ??
    'Pack supplémentaire';

String? downloadablePackForAsset(String asset) {
  if (asset.startsWith('assets/chibis/victory/')) return 'victory-poses';
  if (asset.contains('/avatars/rewards/')) return 'avatars-rewards';
  if (asset.contains('/borders/rewards/')) return 'borders-rewards';
  if (asset.contains('/avatars/classic/')) return 'avatars-classic';
  if (asset.contains('/stickers/rewards/')) return 'stickers-rewards';
  if (asset.contains('/stickers/')) return 'stickers-classic';
  if (asset.contains('/cards/horror/')) return 'horror-cards';
  if (asset.contains('/cards/intense/')) return 'intense-cards';
  if (asset == 'assets/village/horror/wolf_devour_clean.mp4' ||
      asset == 'assets/village/horror/wolf_devour.mp4' ||
      asset == 'assets/village/horror/white_wolf_devour_clean.mp4') {
    return 'horror-devour';
  }
  if (asset.contains('/village/horror/')) return 'horror-village';
  if (asset.contains('/audio/horror/')) return 'horror-ambience';
  final match = RegExp(r'(?:^|/)neural/([^/]+)/').firstMatch(asset);
  final profile = match?.group(1);
  if (profile != null &&
      !profile.startsWith('classic_') &&
      !asset.endsWith('/preview.wav')) {
    return 'voice-${profile.replaceAll('_', '-')}';
  }
  return null;
}

class MissingPackException implements Exception {
  const MissingPackException(this.packId);
  final String packId;
  String get message =>
      'Le pack « ${packLabel(packId)} » n’est pas téléchargé sur cet appareil. Ouvre Mes téléchargements pour l’installer.';
  @override
  String toString() => message;
}

class PackRequestException implements Exception {
  const PackRequestException(this.status);
  final int status;
  @override
  String toString() => 'Réponse de téléchargement $status';
}
