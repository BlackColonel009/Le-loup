# Réponses liées et stickers à collectionner — 3 novembre 2026

## Répondre à un message

Un appui long sur une bulle prépare une réponse. La communauté propose aussi « Répondre » dans le menu du message ; les chats privés et de partie ont une petite flèche de réponse. Une citation dorée avec l'auteur et un extrait apparaît au-dessus de la saisie. La croix annule la réponse et conserve le brouillon. Après un envoi réussi, la saisie se libère ; la citation reste attachée au message envoyé, pour tous les destinataires.

Les citations fonctionnent dans la communauté, entre amis, au conseil, dans la meute et dans les échanges autorisés des amoureux et des Sœurs. Un sticker peut être le message cité ou la réponse. La citation affiche son rôle et son émotion au lieu du code interne du sticker. Les champs de saisie gardent leur identité et leur focus lorsque la citation apparaît ou disparaît.

FastAPI conserve seulement l'identifiant `reply_to`. Le contenu et le nom cités sont résolus côté serveur : le client ne peut pas inventer un auteur, citer une autre conversation privée ni conserver le texte d'un message communautaire masqué par la modération. Un message supprimé devient « Message indisponible ». Les conversations entre amis, citations comprises, s'effacent avec leur fenêtre de 24 heures.

Le moteur Dart donne un identifiant stable aux messages. Il vérifie une référence dans la liste du canal autorisé, ignore les citations fabriquées par le client et conserve l'effacement des échanges nocturnes. Changer de canal efface la réponse en préparation pour éviter de citer un message privé dans le conseil. Le MDJ et les spectateurs conservent leurs droits de lecture existants.

## Second pack de stickers

Les deux planches fournies par Logan donnent **58 stickers individuels** : 38 personnages/actions sur la première et 20 réactions sur la seconde. Une étiquette seule sans dessin sur la première planche est écartée. Les 17 stickers classiques sont conservés dans leur pack distinct.

- Fichiers : `apps/mordeviel/assets/stickers/rewards/*.png`.
- Catalogue commun : `shared/stickers/rewards.json`.
- Pack distant : `stickers-rewards`, « Curiosités du village · Stickers à collectionner ».
- Taille totale : 3 196 862 octets, environ 3,05 Mio. Aucun PNG du pack n'est ajouté au pubspec de l'APK.
- L'extraction des fonds a utilisé **image_gen.imagegen intégré**, avec transparence. Les deux planches transparentes sont conservées dans `shared/stickers/sources/`. Le script `tools/stickers/split_reward_sheets.py` sépare ensuite les éléments et ajoute une marge transparente de 6 pixels. Les originaux dans Downloads ne sont pas écrasés.
- Les **prompts exacts et empreintes** sont archivés dans `tools/stickers/rewards_media.json`.

Le sélecteur propose « Classiques » et « À collectionner ». Les nouveaux accessoires sont assombris avec un cadenas tant que le compte n'en possède pas le droit. Un appui explique le déblocage et propose d'ouvrir les accessoires de la collection. L'envoi demande le téléchargement du bon pack si nécessaire. Les autres joueurs peuvent voir un sticker reçu sans en acquérir la propriété.

## Acquisition, boutique et Collectionneur

Chaque nouveau sticker est un produit `sticker-rewards_…`, de catégorie `sticker` et de thème technique `extras`. Il est verrouillé par défaut, y compris pendant la découverte gratuite générale des cartes. Télécharger ses images ne débloque pas son utilisation.

L'administrateur trouve **Accessoires** dans le dashboard de l'application. Le dashboard web inclut également ces produits dans ses listes existantes. Prix, visibilité, boutique, Collectionneur et bonus utilisent les contrôles déjà présents. Aucun achat n'est possible sans prix publié ; zéro est un prix gratuit valide. Les paiements réels restent désactivés comme avant. Les essais administrateur ciblés et globaux peuvent donner un accès temporaire, sans propriété.

Le Collectionneur conserve ses cinq cartes quotidiennes. Il peut proposer en plus au plus un accessoire sticker, une voix et un environnement. La rotation ajoute occasionnellement un sticker ; l'administrateur peut choisir manuellement jusqu'à huit produits respectant ces limites.

Les défis **ne sont pas inventés ni attribués automatiquement** : chaque entrée porte `unlock: challenge_or_shop`. Leur futur moteur pourra attribuer le produit dans `collection_owned` avec une source de défi. Les conditions et récompenses seront définies avec Logan. En attendant, le dashboard peut proposer une acquisition gratuite publiée ou un essai.

La communauté, les conversations entre amis et la passerelle du jeu en ligne vérifient les droits côté serveur. La sélection locale utilise le compte connecté dans l'application ; le moteur LAN reste un hôte de confiance pour les parties locales. Les fichiers téléchargés et les droits d'utilisation sont deux mécanismes distincts.

## Publication sur le serveur

Après avoir transféré ces modifications par Git, depuis `/var/www/Le-loup` :

```bash
backend/venv/bin/python tools/content/build_packs.py
sudo systemctl restart legendeofwolf
```

La création des produits et l'ajout des colonnes `reply_to` à la base existante se font au démarrage. Les données existantes sont conservées. Les sources des planches et le script de séparation servent à préparer les PNG ; le serveur n'a pas besoin de les redétourer.

Vérifications : citations de texte et de stickers, auteur réel, masquage d'un original, refus d'une référence extérieure au canal, effacement après 24 h, acquisition d'un sticker publié, refus sans droit, interface de réponse, annulation avec brouillon conservé, focus du clavier, sélection verrouillée, alpha et empreintes des 58 fichiers. Un aperçu du composant réel de communauté est enregistré dans `apps/mordeviel/build/previews/chat-reply-community.png` ; le clavier privé a été vérifié à 320 × 568.

Aucun APK n'a été compilé et aucun serveur distant n'a été modifié.
