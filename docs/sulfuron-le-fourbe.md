# Sulfuron · Le Fourbe

Camp Solitaire. Une carte par partie. Les trois éditions sont jouables en local,
en ligne et dans un mélange de cartes. L’édition de la carte de Sulfuron définit
ses protections, indépendamment du décor du salon.

## Pouvoirs nocturnes

Le MDJ choisit quand appeler Sulfuron dans son menu nocturne. Un seul piège par
appel, ou « Passer ». Le réveil et le rendormissement utilisent le narrateur du
salon. Les répliques du personnage utilisent sa voix originale de petit démon
adulte, générée avec le moteur neuronal local déjà utilisé par le jeu.

* **Le Bluff** : choisir un autre survivant. Une carte est annoncée à tous :
  fausse dans 90 % des cas, vraie dans 10 %. Deux nuits doivent séparer deux
  utilisations. Le vrai rôle, le camp, les pouvoirs et le résultat de la Voyante
  ne sont jamais modifiés. Le responsable n’est pas identifié dans l’annonce.
* **La Révélation-piège** : le serveur tire un autre survivant au hasard et montre
  sa vraie carte à tous. S’il meurt directement au prochain scrutin de
  condamnation, Sulfuron reçoit **+1 vie**. Une grâce, un vote blanc, une égalité
  sans sa mort ou une autre cause de mort ne rapporte rien. Le piège expire à la
  fin de ce scrutin. Les vies se cumulent et sont consommées automatiquement.

Les cartes dévoilées par un piège de Sulfuron brûlent comme du papier si le
scrutin suivant les élimine. Cette présentation ne change pas la cause « vote »
utilisée pour les statistiques, les réactions du Chasseur et les autres règles.

## Vies et éditions

| Cause | Classique | Intense | Horreur |
| --- | --- | --- | --- |
| Attaque de la meute | Une vie consommée, survie | Identique | Identique |
| Première condamnation | Mort, même avec des vies | Une vie permet le retour après la sentence | Identique, puis marquer un accusateur |
| Condamnation suivante | Mort | Mort définitive | Mort définitive |
| Poison, tir personnel, chagrin | Mort | Mort | Mort |

En Horreur, après la première résurrection au vote, Sulfuron peut choisir dans
**Actions** un survivant ayant voté contre lui. À son prochain appel nocturne,
sa vraie carte est révélée publiquement. Sans choix, un accusateur vivant est
tiré au hasard. Un accusateur mort ne peut pas être choisi. Cette revanche ne
remplace pas le piège normal de cet appel et ne rapporte pas de vie supplémentaire.
La carte du Maire compte comme un titre : marquer un électeur ne dépend pas du
poids de son bulletin.

Un retour empêche la mort réelle : pas de statistique de décès, pas de mort de
chagrin du partenaire et pas de succession du Maire pour une mort évitée. La
présentation publique du retour au vote attend la fin de la roue de sentence,
ou le passage à la phase suivante si le MDJ n’utilise pas la roue.

## Victoire et confidentialité

Sulfuron gagne **seul** s’il est vivant et que tous les autres survivants
appartiennent au Village. Sa victoire prime alors sur celle du Village. Un autre
solitaire encore en vie empêche cette condition. Une conversion dans la meute
remplace son objectif par celui des loups. Les réactions en chaîne, dont le tir
du Chasseur, se terminent avant de vérifier la victoire.

Les charges et les cibles des pièges sont attachées à la carte : un échange du
Métamorphe transfère cette mémoire à son nouveau détenteur. Les informations
complètes des Bluffs apparaissent dans l’historique final et chez le MDJ,
jamais dans l’annonce publique en cours de partie.

En local, les événements privés de Sulfuron restent silencieux sur les téléphones
des joueurs pour éviter de révéler son identité dans la pièce.

## Fichiers et publication

Les fiches et le Codex sont générés depuis `docs/cards/classic_expansion.json`.
Les règles du serveur sont dans `packages/local_host/lib/src/night_sulfuron.dart`.
La carte Classique et les brèves répliques du personnage sont embarquées ; les
cartes Intense/Horreur et les narrateurs supplémentaires restent dans leurs
packs téléchargeables. Les prix et restrictions utilisent la collection et le
dashboard existants.

Après déploiement du dépôt sur le serveur, publier les nouveaux fichiers des
packs puis redémarrer le service (aucun secret n’est nécessaire dans la commande) :

```bash
cd /var/www/Le-loup
backend/venv/bin/python tools/content/build_packs.py
sudo systemctl restart legendeofwolf
```

Les téléphones doivent installer la nouvelle version de l’application et mettre
à jour les packs Intense/Horreur ou les packs de voix utilisés.
