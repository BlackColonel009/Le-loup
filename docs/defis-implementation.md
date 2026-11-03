# Défis et récompenses — mise en place du 3 novembre 2026

Les 42 exemples de Logan sont maintenant décrits dans `shared/challenges/catalog.json` et suivis par le backend. Le catalogue fixe les conditions, les seuils et les associations aux cosmétiques existants. Les illustrations proposées dans le document initial qui n'existaient pas encore ont été remplacées par des éléments déjà prêts : aucun emplacement de récompense fictif.

## Parcours dans l'application

- Profil personnel → **Mes défis et mes récompenses**.
- Galerie des portraits → **Consulter mes défis**.
- Fin d'une partie en ligne : révélations et victoire, puis un **modal automatique de cadeaux** après l'animation de victoire. Le coffre scintille, présente les objets disponibles et propose **Réclamer mes récompenses**. Le clic attend la confirmation serveur ; le coffre s'ouvre alors, des étoiles jaillissent et le message **Ces trésors sont à vous !** confirme la réception. Le bilan reste accessible ensuite avec les valeurs avant/après.
- Le MDJ ne reçoit pas de victoire ni de défi de rôle pour une partie qu'il anime.
- Les joueurs éliminés avant la conclusion restent éligibles. Quitter l'écran du bilan ne fait pas perdre les récompenses : elles sont déjà enregistrées.
- Un joueur sans compte voit une invitation à se connecter à la communauté.

Les cartes de défis ont des jauges avec remplissage interpolé, une lumière en tête de progression et une présentation dorée lorsqu'un défi est accompli. Les animations réduites du téléphone sont respectées. Le carnet permet de filtrer Tous / En cours / Accomplis. Les petits écrans et le paysage restent défilables.

Deux carillons **originaux**, sans extrait de Nintendo ou de Mario, accompagnent le remplissage et le déblocage. Ils respectent le mode muet et le volume des effets. Leur canal est distinct des voix du MDJ. Fichiers légers inclus : `assets/audio/classic/challenge_progress.wav` et `challenge_unlock.wav`. Script reproductible : `tools/audio/build_challenge_chimes.py`.

## Ce qui fait progresser les défis

Les récompenses portent sur des **parties en ligne terminées entre humains**, avec un compte associé à une place de joueur. Le moteur Dart est la source des faits ; il n'existe aucune API publique permettant d'envoyer ses propres compteurs. Les parties locales, les salons interrompus et les parties avec bots ne débloquent pas ces récompenses. Les résultats d'entraînement restent séparés des statistiques humaines.

Les progrès sont privés et calculés après la fin, y compris pour les rôles déjà éliminés. L'historique et les rôles initialement distribués restent absents des instantanés publics pendant la partie.

- **Premiers crocs** : une partie ayant au moins une dévoration réussie compte une fois, même si plusieurs victimes sont dévorées. Deux parties distinctes sont requises. Les propositions, protections, résistances et victimes sauvées ne sont pas des dévorations.
- **Prédateur nocturne** : compte les victimes réelles de la meute et du pouvoir du Loup Blanc. Les trois nuits d'une même partie pour **Longue chasse** sont un maximum par partie, pas une somme de nuits de plusieurs parties.
- **Voyante** : une véritable vision révélant un rôle de loup ou le camp des loups valide la découverte. Une simple comparaison « même camp / camps différents » ne révèle pas un loup et ne valide pas Regard perçant. Elle compte comme utilisation nocturne pour Vision nocturne.
- **Sorcière** : le sauvetage doit annuler une attaque qui aurait été mortelle et le bénéficiaire doit survivre à cette nuit. Une potion sur un Ancien disposant encore de sa résistance, une infection annulée ou une victime ensuite empoisonnée ne valide pas Une seconde chance.
- **Salvateur** : une attaque réellement bloquée valide la protection si la cible survit à la nuit. Une protection sans attaque ne compte pas. Les deux bénéficiaires de Sous bonne garde sont distincts sur l'ensemble des parties.
- **Chasseur et Loup Blanc** : la cible doit réellement mourir du pouvoir et appartenir alors à la meute.
- **Vote** : le bulletin final doit viser un loup réellement exécuté ; une accusation, un vote remplacé et un Idiot gracié ne comptent pas.
- **Infection** : le bénéficiaire doit être effectivement converti. Une infection encore en attente ou annulée ne suffit pas. Sang nouveau demande une victoire commune du Père et de sa cible dans la meute.
- **Découverte des rôles** : le rôle initialement distribué est retenu ; Villageois et Villageoise partagent le même compteur. Les cartes Intense et Horreur conservent le rôle de base pour compter la diversité. Les thèmes Classique, Intense et Horreur sont suivis séparément.
- **Jours de jeu** : jours UTC distincts de fin de partie, sans série obligatoire. Plusieurs parties le même jour ne donnent qu'un jour.
- **Amis** : trois autres participants doivent être des amis acceptés au moment de la conclusion.

Les défis de victoire personnelle proches (Loup Blanc et Joueur de Flûte) restent deux récompenses distinctes : l'avatar et la bordure. Un même exploit peut donc achever les deux défis correspondants.

## Récompenses et permanence

La vérification d'un nouveau compte rend disponible le cadeau de bienvenue : bordure **Cercle du village**, portrait **Deux Sœurs** et sticker **Villageois — Soupçon**. Il faut maintenant le **réclamer** pour ajouter ces trois objets à la collection. Les quatre portraits de départ sont conservés. Aucun portrait ou cadre n'est équipé automatiquement en remplacement du choix du joueur. Les anciens comptes voient ce cadeau au premier accès au carnet ou à la fin d'une nouvelle partie.

Le défi Habitué du village propose un portrait au choix parmi Chaman, Sœur de bataille et Hérétique. Après récupération du cadeau, son bouton **Choisir mon portrait** permet une sélection personnelle, permanente et unique. Les autres récompenses sont ajoutées lors de la réclamation. Les droits sont inscrits dans les tables existantes `avatar_unlocks`, `border_unlocks` et `collection_owned`, avec une provenance `challenge:<identifiant>`.

**Plus tard** ferme le modal sans perdre le cadeau. Un bandeau et les boutons de chaque défi permettent de le retrouver. Un badge persiste dans le profil de communauté, le carnet personnel et l'entrée sociale de l'accueil. Une erreur réseau laisse la récupération disponible ; deux clics simultanés ne créent qu'une attribution. La migration ajoute `claimed_at` aux progrès existants. Les objets déjà reçus avant cette modification restent utilisables et leur confirmation ne les duplique pas.

Les fichiers des avatars, des cadres illustrés et des stickers restent dans leurs packs téléchargeables. **Gagner l'objet accorde le droit ; installer le pack fournit l'image.** Le téléchargement d'un pack seul ne donne aucun déblocage supplémentaire. Certaines images de réserve restent verrouillées pour de prochains défis ou offres.

La migration récupère une seule fois les anciennes statistiques fiables : parties terminées, victoires et victimes en loup. Les anciens détails de rôle, jours, amis ou nombres de parties de dévoration ne sont pas reconstruits puisqu'ils n'étaient pas conservés. Ces compteurs démarrent avec cette mise à jour.

## Événements administrateur

Dans le dashboard certifié : **Contrôler → Défis et événements officiels**. L'administrateur choisit un identifiant stable, un nom, une date/heure de début et de fin et l'activation. Les dates affichées suivent le téléphone, puis sont transmises en UTC.

Une partie commencée pendant une période active conserve son rattachement à cet événement, même si elle finit après sa clôture. Rejouer plusieurs fois le même événement ne gonfle pas Mémoire des saisons. Un événement absent ou désactivé n'accorde aucun progrès événementiel. Les cadeaux événementiels utilisent actuellement les éléments existants du catalogue, sans nouveau dessin daté.

## Backend et déploiement

Les nouvelles tables SQLite sont créées au démarrage par `challenges.initialize`. Les progrès, statistiques et bilans de fin sont validés dans la même transaction. La récupération des objets et l'enregistrement de `claimed_at` utilisent ensuite une transaction dédiée, idempotente. Une même partie ne peut pas être comptée deux fois, même si le serveur reçoit plusieurs instantanés de fin. Chaque bilan est privé et associé au compte ; il inclut les valeurs avant/après afin que l'application puisse animer une progression exacte. La suppression de compte efface aussi ces nouvelles tables personnelles.

API :

- `GET /challenges/me` — carnet personnel.
- `GET /challenges/matches/{match_id}` — bilan d'une partie du compte.
- `POST /challenges/choices/{challenge_id}` — choix d'un portrait réellement gagné.
- `POST /challenges/claim` — récupération transactionnelle des cadeaux accomplis, une seule fois.
- `GET /challenges/admin/events` et `PUT /challenges/admin/events/{id}` — administration protégée.

Sur Contabo, depuis `/var/www/Le-loup`, après le commit/push et le `git pull` habituels :

```bash
sudo systemctl restart legendeofwolf
curl -fsS https://mordeviel.newtechnologiestg.com/health
```

Aucune nouvelle dépendance ni variable `.env` n'est requise. Les packs de profils et de stickers de la mise à jour précédente doivent déjà avoir été publiés avec `backend/venv/bin/python tools/content/build_packs.py` et installés pour afficher leurs images. Un nouveau build de l'application est nécessaire pour les écrans et les deux petits sons ; aucun APK n'a été compilé par l'agent et aucun serveur distant n'a été modifié.

## Validation

Tests backend : confidentialité, réclamation unique et transactionnelle, deux clics concurrents, reprise après échec, absence de progrès en entraînement, progression 1/2 puis 2/2, droits réels du sticker récupéré, choix unique d'avatar, événements et amis. Tests Flutter : modal automatique, coffre qui s'ouvre après confirmation, boutons toujours visibles avec vingt cadeaux, erreur réseau et reprise, remplissage intermédiaire, jauge à moitié, portrait 320×568 et paysage, entraînement et secret des événements avant la fin. Les scénarios existants des cartes et des profils sont rejoués.

Aperçu produit par les vrais composants Flutter : `apps/mordeviel/build/previews/challenges-recap.png`.

Aperçus du parcours de récupération : `apps/mordeviel/build/previews/reward-claim-available.png` et `reward-claim-received.png`.

## Accueil et repères (3 novembre 2026)

Le bouton lumineux **Défis & récompenses** se trouve en haut du contenu de l’accueil. Après le hurlement d’entrée, un aperçu refermable présente jusqu’à trois défis : cadeaux disponibles, défis en cours, puis défis à commencer avec une jauge vide. Le Collectionneur conserve sa présentation quotidienne, après cet aperçu. Une absence de réseau ne bloque pas le jeu local. Sans connexion au compte, `GET /challenges/catalog` fournit uniquement les définitions publiques, sans aucun progrès personnel.

La barre supérieure affiche l’avatar équipé (photo ou illustration), sa bordure et ses animations, ainsi que le pseudo du compte. Un menu animé voisin réunit Boutique, Mon cercle, Invitations et Défis. Communauté, téléchargements et son restent accessibles directement. Les demandes d’amis, invitations et cadeaux alimentent les badges lumineux du menu et de ses rubriques ; les packs déjà téléchargés à actualiser et les packs du profil équipé manquants alimentent celui des téléchargements. Après une modification du profil, le portrait est rechargé depuis le serveur. Les effets respectent le réglage de réduction des animations et la mise en arrière-plan.

Vérification supplémentaire : une vraie séquence du moteur Dart (attaque nocturne, vote, victoire du village) est transmise au suivi des comptes, y compris le joueur éliminé et le MDJ. Une deuxième transmission ne recompte pas la partie ; un sticker gagné reste inutilisable avant réclamation et devient envoyable après celle-ci.
