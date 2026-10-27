# Communauté et support

**Mise à jour comptes :** l'email est désormais obligatoire et doit être vérifié.
Voir [Comptes et vérification par email](comptes-email.md), qui remplace les anciens
paragraphes ci-dessous décrivant une inscription sans email ni récupération.

L'icône Communauté est en haut à gauche de l'accueil. La communauté utilise
le même API_BASE_URL que le jeu en ligne ; aucune adresse technique n'est
affichée aux joueurs. Elle requiert une connexion Internet et le backend lancé.

## Parcours joueur

- Inscription avec pseudo unique (2–24 caractères), email vérifié et mot de passe
  (8–128). La session de l'app est conservée dans le stockage sécurisé pendant
  24 heures, y compris après fermeture de l'app ou retour à l'accueil.
- Discussion publique, questions et partages sous forme de texte/liens.
  Actualisation toutes les cinq secondes et manuelle ; 50 derniers messages.
- Signalement d'un message au support.
- Support privé : création d'une demande, liste de ses demandes, consultation
  des réponses et ajout de précisions. Actualiser la conversation pour une réponse
  reçue pendant sa consultation. Le joueur ne voit jamais les tickets des autres.
- Mention « Réponse visée sous 48 h ». Il s'agit d'un objectif humain ; aucun
  mécanisme ne garantit une réponse en 48 h et aucune IA n'est encore activée.

## Stockage

Cette nouvelle fonction ajoute une base SQLite persistante, indépendante des
salons de jeu en mémoire. Fichier par défaut : backend/data/community.sqlite3,
ignoré par Git. Définir LE_LOUP_COMMUNITY_DB pour un autre emplacement.
Sauvegarder ce fichier sur Contabo et conserver son volume lors des déploiements.
Les mots de passe sont dérivés avec scrypt et sel aléatoire, les jetons de session
sont aléatoires et leur empreinte seule est stockée. Les nouvelles sessions
expirent après 24 heures, sans renouvellement automatique à chaque consultation.
Les routes limitent les tentatives de connexion, les messages et les demandes.

Cette première version n'inclut pas encore la récupération d'un mot de passe
oublié, les pièces jointes, les notifications push ni l'interface de modération
dans l'app. Ces fonctions seront à compléter avant une ouverture à grande échelle.

## Répondre et modérer

Configurer LE_LOUP_SUPPORT_TOKEN dans l'environnement privé du serveur avec un
secret long et aléatoire. Ne jamais l'inclure dans Flutter, Git ou une invitation.
Sans cette variable, les accès administrateur sont désactivés.

Dans l'API /docs ou un outil HTTP, fournir l'en-tête Authorization: Bearer SECRET
aux routes suivantes :

- GET /community/admin/tickets : demandes avec leur numéro et auteur.
- GET /community/admin/tickets/{id} : conversation privée.
- POST /community/admin/tickets/{id}/reply avec {"text":"Votre réponse"} :
  réponse identifiée Support dans l'app et statut « Réponse disponible ».
- GET /community/admin/reports : signalements publics.
- DELETE /community/admin/messages/{id} : masque le message dans le chat.

Aucun email ou message à un tiers n'est envoyé automatiquement. Les réponses
sont consultables dans le support privé de l'application.

## Annonces officielles et FAQ

Les onglets Annonces et FAQ sont disponibles après connexion. Leur lecture
est aussi accessible depuis le formulaire d'inscription sans compte.
GET /community/info retourne le contenu officiel stocké dans SQLite. La FAQ
se recherche dans l'application ; les joueurs ne peuvent pas publier une annonce
officielle. Le contenu initial est ajouté une seule fois à la création de la table.

Avec l'en-tête administrateur déjà décrit :

- POST /community/admin/content publie {"kind":"announcement","title":"Titre","body":"Texte"}.
- kind peut aussi être faq : title contient la question, body la réponse.
- PUT /community/admin/content/{id} modifie une publication existante.
- DELETE /community/admin/content/{id} la masque.

L'assistant IA reste une évolution ultérieure ; les réponses présentes sont des
articles rédigés, pas une génération automatique.

## Boutique en aperçu

Un bouton Boutique est placé sous Communauté dans la colonne gauche de l'accueil.
GET /shop/catalog fournit les rubriques : thèmes complets, apparences de cartes,
voix OFF, animations et cosmétiques personnels. Un aperçu intégré reste visible
si le backend est inaccessible. Il ne débloque et ne facture rien.

Chaque bouton porte « Achat à venir » et affiche « Non disponible ».
POST /shop/purchase refuse également les achats avec HTTP 409, même si un client
essaie de contourner l'interface. Aucun prestataire de paiement ni prix n'est
configuré. Le bandeau indique : « Profitez de l’application totalement disponible
pour le moment. » Les packs existants conservent leur accès gratuit de test ;
les collections en préparation sont identifiées dans leur description.
