# Profils, bordures et suggestions de stickers — 3 novembre 2026

## Deux packs de récompenses

Les deux planches de Logan sont séparées en **15 médaillons de profil et 25 bordures illustrées**. Les cadres ouverts servent de bordures avec un vrai centre transparent ; les illustrations pleines servent de profils. Les noms apparaissent dans l'interface, sans les légendes imprimées sous les images.

| Pack | Contenu | Taille |
|---|---|---|
| `avatars-rewards` · Médaillons de légende | 15 profils | 1 654 507 octets, environ 1,58 Mio |
| `borders-rewards` · Cadres de légende | 25 cadres | 2 282 951 octets, environ 2,18 Mio |

Les PNG se trouvent dans `shared/avatars/rewards/portraits/` et `shared/avatars/rewards/borders/`. Ils restent **hors des ressources de l'APK**. Le catalogue `shared/avatars/rewards.json` décrit les 40 éléments ; les catalogues habituels des avatars et bordures contiennent également leurs métadonnées. Le pack classique conserve ses 21 images, dont le Créateur, et les quatre portraits de départ restent accessibles.

Les profils et les bordures personnalisent le compte. Tous les nouveaux éléments sont verrouillés par défaut, avec contrôle côté serveur. Le futur moteur de défis pourra enregistrer les récompenses dans `avatar_unlocks` ou `border_unlocks`, avec le compte concerné et la source du défi. Aucune condition de défi ni attribution automatique n'est activée par cette mise à jour.

## Choisir et afficher un cadre

La galerie du profil propose **Animées** et **Illustrées** pour les bordures. Les bordures colorées existantes gardent leur animation. Les nouvelles bordures utilisent les illustrations de Logan, avec le portrait dessiné derrière le cadre et ses ornements. L'ouverture intérieure est calibrée par image ; les chauves-souris, serpents, lanternes et autres décorations peuvent passer devant le portrait, comme sur le dessin d'origine.

Les boutons « Profils à gagner » et « Bordures à gagner » ouvrent le téléchargement des packs correspondants. Une récompense accordée ne peut être sélectionnée qu'après disponibilité de son pack sur l'appareil. Télécharger les fichiers n'accorde pas le droit de les équiper. Le Créateur conserve son statut et sa bordure réservée.

## Suggestions dans les discussions

Une rangée de stickers apparaît au-dessus de la saisie lorsque les mots du brouillon correspondent à des mots clés. Exemples : « bonjour », « merci », « peur », « vote », « loup », « potion », « amour », « chut », « mdr » ou « je ne comprends pas ». La recherche ignore les accents et reconnaît les préfixes à partir de trois lettres. Elle utilise les derniers mots pour limiter les propositions à l'intention actuelle du message.

La correspondance est **locale** : aucune requête contenant le brouillon n'est envoyée au serveur. Les mots clés sont éditables dans `shared/stickers/classic.json` et `shared/stickers/rewards.json`, puis synchronisés avec `tools/stickers/sync_catalog.py`.

Les suggestions sont intégrées à la communauté, au conseil, à la meute, aux échanges autorisés des amoureux et des Sœurs et aux discussions entre amis. Elles proposent les stickers classiques et les récompenses auxquelles le compte a accès. Les éléments verrouillés restent consultables dans le sélecteur complet. Une proposition demande le bon pack si nécessaire, puis utilise l'envoi habituel et conserve le texte en brouillon. Une réponse citée reste attachée au sticker envoyé. Si le canal se ferme pendant le téléchargement, l'envoi est abandonné.

Les suggestions utilisent un écouteur du champ de texte : les messages ne sont pas reconstruits à chaque frappe. La saisie garde son focus. Les zones de composition deviennent défilables sur les petits écrans avec clavier ; l'en-tête décoratif se replie lorsqu'il manque de hauteur.

## Sources, détourage et reconstruction

Le détourage utilise **image_gen.imagegen intégré** avec transparence. Les planches détourées et les deux corrections d'ouverture (Chasseur et Ancien) sont conservées dans `shared/avatars/reward_sources/`. Les **prompts exacts, fichiers sources et empreintes** sont dans `tools/content/profile_rewards_media.json`. Les originaux fournis dans Downloads sont conservés.

Les scripts de préparation sont :

```bash
python tools/content/split_profile_rewards.py
python tools/content/sync_profile_rewards.py
python tools/content/sync_avatars.py
python tools/stickers/sync_catalog.py
python tools/content/build_packs.py
```

Les PNG préparés et les métadonnées générées sont déjà présents dans le projet. Sur Contabo, après le prochain `git pull`, seul le renouvellement du catalogue publié est nécessaire, depuis `/var/www/Le-loup` :

```bash
backend/venv/bin/python tools/content/build_packs.py
sudo systemctl restart legendeofwolf
```

## Vérifications

Les tests couvrent les verrous, les vrais déblocages par compte, le choix du pack correct, la conservation des quatre avatars de départ et du profil Créateur, les mots clés, les accents, les propositions limitées aux droits du compte et le focus du clavier. La communauté avec onglets et les messages privés sont vérifiés sur un écran de 320 × 568 avec clavier ouvert. Les 40 PNG sont contrôlés pour leur alpha, leurs dimensions, leurs empreintes et leur exclusion de l'APK.

Les aperçus `apps/mordeviel/build/previews/profile-rewards.png` et `sticker-suggestions.png` viennent des composants Flutter réellement rendus avec les packs installés dans un cache de test. Les planches de contact `borders-rewards-all.png` et `avatars-rewards-all.png` montrent l'ensemble des fichiers extraits.

Aucun APK n'a été compilé et aucun serveur distant n'a été modifié.

Les défis ont ensuite été mis en place : voir [Défis et récompenses — fonctionnement livré](defis-implementation.md). Une partie des profils, bordures et stickers de cette réserve reçoit désormais des conditions d'obtention effectives.
