# Ajustements du gameplay du 29 octobre 2026

- Chasseur : trois coups de feu, impacts agrandis, cri après les tirs si la carte révélée appartient aux loups.
- Sentence au vote : séparation de la carte selon son édition. Classique sans sang, Intense avec arcs et crépitement électriques, Horreur avec gouttelettes de sang. Les autres causes conservent leurs effets dédiés.
- Potion de vie : animation privée de seconde chance, aura dorée et rotation. Il s’agit toujours de prévenir l’attaque nocturne, pas de ressusciter un joueur déjà éliminé. Aucun écran de réanimation si la cible meurt malgré le sauvetage.
- Le réglage MDJ « Révéler la Sorcière au joueur sauvé » est désactivé par défaut. Si activé, seul le joueur sauvé reçoit son pseudo. La nouvelle réplique utilise la voix Vieille Sorcière, disponible dans son pack actualisé.
- Protection du Salvateur : deux lueurs en Classique, bulle dorée en Intense et Horreur, attachées à la maison exacte. Visibilité limitée aux participants autorisés.
- Horreur : approche du hibou vers 32 secondes du cycle nocturne, retour sur sa branche, passages intermittents de chauves-souris de jour et de nuit. Réglages de sons, frayeurs et animations réduites respectés.
- Conseil : le champ de saisie conserve son état lors de l’ouverture du clavier.
- Amis : conversation privée remise à zéro 24 h après le premier message ; accès réservé aux amis acceptés, nettoyage serveur et suppression avec le compte.
- Statistiques : résultats en ligne humains dans le profil public ; parties avec bots dans une rubrique personnelle distincte. Actualisation du profil toutes les 10 secondes. Le MDJ ne reçoit pas de victoire de camp. Les anciens résultats non enregistrés ne peuvent pas être reconstruits après fermeture du moteur.

## Déploiement

Après transfert des modifications et installation habituelle des dépendances sur Contabo :

```bash
cd /var/www/Le-loup
sudo backend/venv/bin/python tools/content/build_packs.py
sudo systemctl restart legendeofwolf
```

Rebuilder l’application puis actualiser le pack Vieille Sorcière sur le téléphone. Les modifications locales n’ont pas été déployées automatiquement. Aucun APK compilé pendant cette intervention.
