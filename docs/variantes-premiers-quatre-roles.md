# Premières variantes jouables — Voyante, Métamorphe, Salvateur et Loup-Garou

Cette mise à jour rend jouables les huit propositions Intense/Horreur de ces quatre rôles. Les autres rôles conservent leurs pouvoirs actuels. L’équilibrage reste à valider en parties avec Logan ; les tests ci-dessous valident le fonctionnement, pas un taux de victoire équilibré.

## Composition et partie mixte

Dans la préparation du salon, le MDJ choisit l’environnement puis ouvre « Collections mélangées ». Chaque exemplaire dispose de son sélecteur d’édition. Un Loup-Garou Classique et un Loup-Garou Horreur peuvent cohabiter. Les rôles spéciaux restent uniques dans la composition actuelle ; cette première version n’autorise pas plusieurs Voyantes ou Salvateurs.

La carte distribuée possède son rôle, son édition et une identité interne stable. Le décor ne remplace pas son pouvoir. Les dos des cartes secrètes ne révèlent pas l’édition de leurs propriétaires. Le Codex annonce la composition et décrit chaque variante avant la partie. Le dos de la carte personnelle reprend les règles et le réglage de la Voyante. Toute modification de composition demande une nouvelle confirmation « prêt ».

Les anciens sélecteurs par rôle restent compatibles. Les nouveaux exemplaires utilisent des clés `role#0`, `role#1` dans `card_styles`, validées par le moteur selon les quantités du paquet. Ces indices désignent les cartes du paquet avant mélange, jamais les places des joueurs. Les droits de collection sont vérifiés aussi pour ces choix individuels.

## Règles livrées

| Rôle | Intense | Horreur |
|---|---|---|
| Voyante | **Arbitre des âmes** : une vision habituelle OU une comparaison de deux autres vivants par nuit. La comparaison dit seulement même camp/camps différents. | **Oracle interdit** : une fois, deux visions au lieu d’une pendant la même nuit. Les deux cibles sont prévenues sans connaître l’auteur. Le réglage rôle exact/camp uniquement s’applique. |
| Métamorphe | **Marchand de visages** : première nuit, consultation des camps de deux vivants, puis échange de ces deux cartes ou renoncement. La consultation consomme l’utilisation. | **Voleur d’âmes** : peut reporter son unique échange à une autre nuit. Son appel reste avant les autres pouvoirs ; le MDJ peut le passer. Les deux cibles reçoivent leur nouvelle carte immédiatement. |
| Salvateur | **Gardien royal** : protection habituelle ; une fois, renforcement qui bloque aussi le poison. Pas d’auto-renforcement. Le tir du Loup Blanc reste possible. | **Gardien sacrificiel** : protection habituelle OU sacrifice unique. Une mort nocturne directe de la cible (meute, Alpha, poison ou Loup Blanc) est redirigée vers le Gardien. Ni vote, ni tir du Chasseur, ni chagrin, ni infection non mortelle ne sont bloqués. |
| Loup-Garou | **Traqueur** : une fois pendant l’éveil des loups, flair privé d’une cible vivante hors meute. Détecte un Salvateur ou la résistance intacte de l’Ancien, sans identifier le rôle. Le vote de chasse reste disponible. | **Dévoreur de secrets** : demande un voile sur la victime commune. La charge n’est consommée que si celle-ci est effectivement dévorée. Le rôle reste caché pendant la journée et la nuit suivantes, puis est dévoilé au réveil suivant. Une fin de partie révèle tout immédiatement. |

Les camps comparés sont Village, Loups et Solitaires. Deux Solitaires ne sont pas forcément alliés. Les protections du Salvateur, normales ou spéciales, ne permettent pas de viser la même personne deux nuits consécutives. Une charge de renforcement ou sacrifice est consommée lorsqu’on confirme cette action, même si aucune attaque ne survient.

Plusieurs demandes de voile sur la même victime ne consomment qu’une charge, celle de la première demande encore éligible. Les autres loups gardent leur charge. Les rôles masqués par le réglage général « ne pas révéler les morts » ne deviennent pas publics à la fin du voile ; la fin de partie conserve sa révélation générale habituelle. Le MDJ connaît toujours les rôles.

## Échanges et informations

L’échange transfère le rôle complet, l’édition, les charges de variantes, les potions consommées, la résistance de l’Ancien et la dernière cible du Salvateur. Infection, amour et charme restent attachés aux personnes. Une carte échangée ne récupère aucun pouvoir consommé. La reconnaissance des Sœurs suit leurs cartes.

Résultats des visions, comparaison, consultation des camps et flair sont privés à leur auteur et au MDJ. Les cibles de l’Oracle reçoivent seulement une notification sans auteur. L’historique final distingue les nouvelles actions et les effets. La source d’un sacrifice est conservée dans l’historique autoritaire pour compter correctement une victime de la meute ; un sacrifice provoqué par un poison ne donne pas de victime aux loups.

## Vérification et déploiement

Tests du moteur pour chaque variante, charges uniques, cibles interdites, échange tardif, secrets, potions transférées, fin du voile et victoire immédiate. Tests supplémentaires des interactions Loup Blanc/infection/sacrifices multiples ; tests des écrans de comparaison et de protection ; distribution d’éditions individuelles et demande de voile via le vrai serveur FastAPI/Dart. Les scénarios réseau des rôles classiques restent valides.

Mettre à jour ensemble le backend, `packages/local_host` et l’application sur les téléphones. Aucun nouvel asset lourd, pack média, service ou variable d’environnement n’est requis. Pas de compilation APK effectuée.
