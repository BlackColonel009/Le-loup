String packLabel(String id) =>
    const {
      'stickers-classic': 'Stickers · Émotions du village',
      'horror-cards': 'Horreur · Cartes',
      'horror-village': 'Horreur · Village et sentences',
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
  if (asset.contains('/stickers/')) return 'stickers-classic';
  if (asset.contains('/cards/horror/')) return 'horror-cards';
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
