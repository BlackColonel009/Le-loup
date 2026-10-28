# Administration certifiée

## Créer ton premier compte sur le serveur

Dans l'environnement Python du backend, après définition de MORDEVIEL_COMMUNITY_DB
si nécessaire, exécuter :

```powershell
backend/.venv/Scripts/python.exe -m mordeviel_api.create_admin --nickname "Logan R.D" --email "votre-adresse@votre-domaine.fr"
```

Sur Contabo/Linux, utiliser le python de son environnement virtuel. La commande
demande le mot de passe deux fois sans l'afficher. Aucun mot de passe n'est
prédéfini, écrit dans Flutter ni publié dans le dépôt. Si le compte existe déjà,
son mot de passe actuel est requis pour le promouvoir. La commande doit viser
le même fichier SQLite que FastAPI. L'inscription publique ne peut jamais
attribuer le rôle admin, quel que soit le pseudo choisi.

Ensuite : Communauté → J'ai déjà un compte → connexion avec ce compte.
La vérification par email est obligatoire avant l'accès au dashboard, comme pour
tous les comptes. Voir [la configuration SMTP et les parcours](comptes-email.md).
Le bouton Dashboard administrateur apparaît uniquement pour le rôle admin,
avec la mention Administrateur certifié. La certification désigne un rôle
officiel accordé par l'exploitant du serveur, pas une vérification externe.
Les endpoints vérifient ce rôle sur chaque requête. Un pseudo « admin » seul
ne donne aucun droit. Le secret de support historique reste utilisable par
l'exploitant côté serveur, sans jamais être inclus dans l'app.

## Dashboard

- Contrôler : activer/désactiver séparément les nouvelles parties locales et
  en ligne, et personnaliser le message de maintenance.
- Boutique : créer/modifier une offre, son prix, devise EUR/USD/XOF, visibilité
  et affichage promotionnel. Les prix sont préparatoires : les achats restent
  désactivés côté serveur et dans l'app, sans paiement ni débit.
- Comptes : rechercher, bannir/débannir un compte de la communauté, lever une
  restriction du chat. Les comptes administrateurs sont protégés contre le ban.
  Le ban communautaire ne bloque pas une partie anonyme, qui n'utilise pas le
  compte communautaire.
- Support : lire et répondre aux tickets privés ; consulter les signalements
  et masquer les messages signalés.
- Publications : créer, modifier ou masquer une annonce officielle ou une FAQ.

Les modifications sont conservées dans SQLite ; les opérations de contrôle,
offre et bannissement sont consignées dans admin_audit sans mot de passe.

## Chat : trois avertissements puis trois heures

La vérification s'applique au chat public, côté serveur. Un message contenant
un terme déconseillé est refusé, sans être publié, avec Avertissement 1/3 puis
2/3. La troisième tentative consécutive bloque l'écriture pendant 10 800 secondes.
Les messages valides acceptés remettent le compteur à zéro. Après expiration,
l'utilisateur peut écrire à nouveau. L'état est conservé malgré déconnexion
ou redémarrage. Pendant la restriction, il peut lire et contacter le support.

Le filtre lexical traite les majuscules, accents et certaines écritures
contournées, en évitant les sous-chaînes à l'intérieur des mots ordinaires.
La liste est dans backend/src/mordeviel_api/moderation.py. Il ne comprend pas le
contexte et ne détecte pas toutes les insultes ; des mots ambigus peuvent être
refusés. L'administrateur peut lever une sanction erronée. Les tickets privés
ne sont pas filtrés pour permettre les demandes d'aide et contestations.

## Maintenance et hors connexion

À l'appui sur Jouer en ligne ou Jouer en local, l'app consulte GET /status et
affiche le message configuré si le mode est désactivé. Le dernier état reçu est
conservé sur l'appareil. Sans réponse rapide, le local utilise ce cache ; un
appareil jamais connecté conserve le fonctionnement local par défaut. Il n'est
donc pas possible d'imposer à distance une nouvelle maintenance à un téléphone
hors connexion. Le serveur refuse aussi la création et l'accès joueur aux salons
en ligne pendant la maintenance. Les parties déjà en cours restent actives.
