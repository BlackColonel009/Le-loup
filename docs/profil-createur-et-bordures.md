# Profil Créateur et bordures — 2 novembre 2026

Le portrait du loup approuvé dans la maquette est publié dans le pack existant **avatars-classic**. Son fichier source est `shared/avatars/artwork/creator-wolf.jpg` (267 076 octets), hors des ressources Flutter. Le catalogue contient maintenant 21 portraits : les vingt Classiques et le portrait réservé au Créateur. Les quatre portraits de départ restent accessibles à tous, les seize autres Classiques restent soumis aux futurs défis.

Les profils personnels, les profils visités et le chat communautaire utilisent le même portrait et la même bordure renvoyés par le serveur. Le Créateur dispose d’un sceau doré animé, d’un insigne « CRÉATEUR » et de la signature « Fondateur de Mordeviel · by Logan R.D ». Son pseudo n’est pas modifié. Le premier équipement est automatique ; un autre portrait ou une photo personnelle restent possibles et les choix suivants sont conservés.

## Identité réservée au compte

Le serveur lie le style à un identifiant de compte administrateur, jamais à son pseudo ni à une valeur envoyée par l’application. Si un seul administrateur existe au premier accès, son identifiant est enregistré comme celui du Créateur. Les autres administrateurs ne reçoivent pas ce privilège. Lorsqu’il existe déjà plusieurs administrateurs, le serveur attend une attribution explicite depuis le terminal :

```bash
cd /var/www/Le-loup
backend/venv/bin/python -m mordeviel_api.set_creator --nickname "Logan R.D"
```

Adapter ce pseudo au pseudo exact du compte existant. Cette commande ne crée pas de compte, ne change pas le mot de passe et ne modifie pas les autres droits administrateur. L’identité est conservée lors d’un changement de pseudo et retirée si le compte perd son rôle administrateur. La suppression du compte conserve un marqueur empêchant un nouvel utilisateur de récupérer l’insigne par réutilisation de son identifiant.

## Bordure prémium.

La personnalisation du profil présente huit bordures colorées : Rubis ardent, Ambre solaire, Or céleste, Émeraude sylvestre, Azur lunaire, Indigo mystique, Améthyste nocturne et Arc-en-ciel légendaire. Elles sont **verrouillées pour tous les comptes**, y compris les administrateurs, avec la mention « Défis ou achat à venir ». Une pression ouvre un aperçu animé ; aucun achat ni défi fictif ne les débloque. Le sceau du Créateur est une bordure distincte, réservée à son propriétaire.

La table `border_unlocks` prépare les futures récompenses et acquisitions vérifiées. Aucun endpoint joueur ne permet de créer ces droits. `PUT /community/avatar/border` vérifie l’autorisation réelle, même si la requête tente de modifier la valeur `locked`. Le choix « Sans bordure animée » reste disponible. Les droits et le style équipé sont propres au compte et supprimés avec celui-ci.

Les animations sont procédurales : seules les couleurs et les types d’effets sont décrits dans `shared/avatars/borders.json`. Aucun film, GIF ou ensemble d’images de bordures n’est ajouté à l’APK. Les vignettes du catalogue sont fixes pour économiser les ressources ; l’aperçu et les portraits équipés animent les reflets. La mise en arrière-plan, les mouvements réduits et le mode allégé arrêtent ces animations.

## Publication et téléchargement

Après avoir publié les changements puis effectué le `git pull` sur le serveur :

```bash
cd /var/www/Le-loup
backend/venv/bin/python tools/content/build_packs.py
sudo systemctl restart legendeofwolf
```

Le nombre de packs reste **13** : le pack d’avatars existant reçoit une nouvelle version. Dans l’application reconstruite, ouvrir le profil puis « Changer mon portrait ». La galerie rafraîchit le catalogue ; le bouton du pack permet d’en télécharger la mise à jour. Le nouveau portrait n’est pas inclus dans l’APK et l’ancienne version du pack n’est pas supprimée du serveur.

L’illustration a été générée avec l’outil intégré `image_gen.imagegen` et approuvée en maquette avant intégration. Sa provenance, son prompt et ses empreintes sont archivés dans `shared/avatars/creator-source.json`. Aucun nouvel appel de génération n’est nécessaire.

L’intégration est préparée dans le projet local. Aucun APK n’a été compilé et aucun serveur distant n’a été modifié.

## Vérifications

20 tests Flutter ciblés et 11 tests backend passent : verrouillage effectif, propriétaire unique, changement de portrait, partage du style entre profils et messages, téléchargement vérifié par empreinte, suppression des données, animations et pauses, petits écrans et texte agrandi. L’analyse Dart et Ruff ne signalent aucune anomalie dans les fichiers concernés. Un aperçu natif avec le vrai portrait et les huit bordures a été exporté et inspecté dans `apps/mordeviel/build/previews/avatar-borders.png`.
