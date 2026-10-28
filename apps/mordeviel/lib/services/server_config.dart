/// Adresse publique commune aux salons, à la communauté et à la boutique.
/// Peut être remplacée au lancement avec --dart-define=API_BASE_URL=...
const publicSiteUrl = 'https://mordeviel.newtechnologiestg.com';

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: publicSiteUrl,
);
