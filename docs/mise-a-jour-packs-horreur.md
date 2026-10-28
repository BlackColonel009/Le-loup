# Mise à jour : contenus téléchargeables et thème Horreur

Demandée par Roland DJAGBA Alias Logan le 28 octobre 2026.

## Périmètre validé

- Packs de stickers et profils audio supplémentaires servis par FastAPI, téléchargés et conservés sur le téléphone, avec progression, reprise, contrôle SHA-256, mise à jour et suppression.
- Voix classiques et courts extraits de test inclus dans l’application. Les packs restent utilisables hors connexion après installation.
- Le MDJ partage son profil ; en ligne, chaque appareil concerné doit le télécharger. En local, diffusion d’ambiance uniquement chez le MDJ.
- Maire : fonction publique cumulable avec un rôle secret, élu le jour, bulletin double sur une cible, vote blanc simple. À sa mort, désignation d’un successeur vivant avant reprise des réactions. À expiration, nouvelle élection au prochain jour si la partie continue. Aucune succession ne bloque une victoire acquise.
- Le Maire possède une carte Classique, une carte Intense et une carte Horreur, consultables dans la collection et depuis sa fonction pendant la partie. Il n’est jamais distribué à la place d’un rôle secret.
- Deux Sœurs : deux cartes Village obligatoirement ensemble ; reconnaissance privée la première nuit ; aucun chat privé permanent ; la survivante continue normalement. Une infection ne prévient pas l’autre sœur.
- Cartes Horreur : gothique inquiétant, personnages reconnaissables, moins de sang et aucune mutilation explicite. Les huit sentences restent strictement identiques aux fichiers utilisateur, sans retouche (précision demandée pendant le développement). Mêmes règles que les autres thèmes.
- Village Horreur : décor et maisons en rendu 3D illustré, maisons éliminées distinctes, brume, chauves-souris en groupe et rare hibou aux yeux jaunes approchant la caméra. Ambiances discrètes (hululement, rire de sorcière), avec réduction des frayeurs et des animations. Événements purement décoratifs, indépendants des rôles.
- Tous les contenus Horreur restent téléchargeables ; les originaux utilisateur sont conservés.

## Validation

Pas de compilation APK : l’utilisateur réalise le build et les essais sur téléphones. Les contrôles de logique, de contrat réseau, de sécurité des téléchargements et d’analyse statique sont réalisés pendant l’intégration.

## Utilisation et publication

L’accueil et les paramètres audio donnent accès à **Mes téléchargements**. Douze modules sont publiés : huit profils vocaux supplémentaires, un pack de stickers et trois modules Horreur (cartes, village/sentences, ambiance). Les deux voix classiques et les dix extraits de test restent dans l’application. Le téléphone conserve les anciens fichiers pendant une mise à jour et valide chaque nouveau fichier avant de l’utiliser. Les fragments `.part` servent à la reprise ; un fichier corrompu n’est jamais activé. Les répliques de personnages appartenant à une voix supplémentaire nécessitent son pack ; en son absence, la présentation visuelle et les jingles continuent sans attente de lecture impossible.

Les membres qui reçoivent un sticker peuvent récupérer son image individuellement. Le sélecteur demande l’installation du pack pour choisir confortablement parmi les personnages. Un joueur doit télécharger les ressources du salon avant de se déclarer prêt : visuels Horreur, et voix choisie si sa diffusion est nécessaire. En local, seul le MDJ a besoin du pack audio. Les packs sont gratuits dans cette version.

Le thème utilise des illustrations au rendu 3D, pas des modèles 3D temps réel. La disposition est prévue pour vingt maisons. Les effets décoratifs ne dépendent d’aucune information secrète. Les frayeurs se coupent dans les paramètres audio et respectent la réduction des animations du système, la pause de partie, la mise en arrière-plan et le volume des effets. En local, les sons de ces événements restent chez le MDJ.

Après publication des modifications dans Git, sur Contabo :

```bash
cd /var/www/Mordeviel
git pull
python3 tools/content/build_packs.py
sudo systemctl restart mordeviel
curl -fsS https://mordeviel.newtechnologiestg.com/content/packs
```

Le script utilise seulement Python standard et conserve les originaux. Les fichiers immuables et leur catalogue sont produits dans `backend/content/packs/` (ignoré par Git). Au premier démarrage, FastAPI les prépare si le catalogue n’existe pas. Relancer le script après chaque changement d’assets. Il conserve les anciennes versions pour permettre les téléchargements déjà commencés. Le service doit pouvoir lire ce répertoire ; adapter `MORDEVIEL_CONTENT_ROOT` seulement pour utiliser un autre volume et y publier les fichiers. Les mobiles doivent installer la nouvelle version de l’application avant de rejoindre un salon utilisant les nouveaux rôles.

Les nouveaux visuels sont dans `apps/mordeviel/assets/cards/horror/` et `apps/mordeviel/assets/village/horror/`. Les modes, références et prompts sont conservés dans `docs/horror-image-prompts.json` et `docs/horror-village-prompts.json`. Génération avec l’outil intégré image_gen, aucune retouche des originaux utilisateur et aucune substitution des huit sentences fournies.

Les cartes du Maire Classique et Intense sont `apps/mordeviel/assets/cards/mayor.png` et `apps/mordeviel/assets/cards/intense/mayor_intense.png`. Leurs prompts et celui du hibou perché sont conservés dans `docs/mayor-and-owl-prompts.json`. L’audit des 32 images est dans `docs/horror-assets-audit.json`. Les huit sentences sont vérifiées par comparaison SHA-256 avec les sources utilisateur.

Le bilan des ressources est dans `docs/content-packs-audit.json` : environ 61,7 Mio de moins embarqués par rapport aux fichiers suivis avant la mise à jour, malgré les nouvelles cartes communes. Ce chiffre concerne les ressources non compressées et ne prédit pas le poids exact de l’APK. Les douze packs représentent environ 164,5 Mio si tous sont installés ; ils sont facultatifs selon les usages. Les 339 fichiers publiés ont été vérifiés par taille et SHA-256.

Contrôles : suite Flutter (dont nouveaux tests de succession, vote double, reconnaissance privée et reprise des packs), 16 tests backend incluant la partie en ligne réelle, 17 scénarios Dart moteur/réseau local, analyse statique sans erreur. Le scénario étendu utilise dix-neuf joueurs pour dix-huit rôles, puisque les Sœurs occupent deux cartes. Aucune connexion au serveur Contabo et aucun build d’APK effectués.

## Mise à jour suivante, à discuter après validation

Préparer avec Logan un gameplay Horreur plus difficile : nouveaux dilemmes et mécaniques, équilibre des camps et compréhension des joueurs. Rien de cette seconde phase ne modifie les pouvoirs de la présente mise à jour. Le Maire et les Deux Sœurs sont communs aux thèmes.
