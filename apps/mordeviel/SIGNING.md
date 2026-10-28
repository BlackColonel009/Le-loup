# Identité et signature

Application : **Mordeviel**

Auteur : **Roland DJAGBA Alias Logan**

Crédit affiché : **by Logan R.D**

Cette identité figure dans AUTHOR.json, les métadonnées Windows, les mentions
iOS et Web et les crédits de l'application. Les identifiants techniques Android
et iOS restent inchangés pour conserver les installations et leurs données.

Android utilise encore le certificat de développement configuré par Flutter,
y compris dans la configuration release actuelle. Aucune clé privée existante
n'a été remplacée. Les fichiers de mentions d'auteur ne signent pas un binaire.
Un certificat de publication et un keystore privé seront à configurer avant
distribution officielle ; l'identité d'auteur souhaitée est celle ci-dessus.
Ne pas committer de keystore, mot de passe ni clé privée dans le dépôt.

Les icônes sont régénérables avec `tools/update_app_icons.ps1`, depuis le logo
transparent de `assets/branding/logo.png`. Le logo source fourni est conservé.
