# Annonces, brouillons et emails

## Administration depuis le site

Dans `/administration`, après connexion avec un compte administrateur, la rubrique
**Les annonces du village** permet de créer, modifier et masquer les mêmes annonces
que l’application. La vitrine et le jeu utilisent la source commune
`/community/info` ; il n’existe pas de publication séparée pour le site.

Le titre et le texte sont sauvegardés en brouillon dans le stockage local du
navigateur, par compte et par publication. Ils sont restaurés après rechargement
et reconnexion dans ce navigateur, sans être publiés. Ces brouillons ne sont pas
synchronisés avec ceux de l’application ni avec un autre appareil. Un stockage
indisponible est signalé ; le formulaire garde alors son texte tant que la page
reste ouverte. « Effacer ce brouillon » ne modifie pas une annonce déjà publiée.

Après publication, **Envoyer / suivre les emails** affiche les compteurs et demande
confirmation avant de programmer l’envoi. Il utilise les mêmes endpoints et le
même thème de mail que l’application ; les règles de désinscription, de version
de contenu et de protection contre les doublons restent identiques. La publication
n’envoie jamais automatiquement un email. Une panne SMTP ne retire pas l’annonce
du site ou du jeu. Le bouton **Actualiser les annonces** recharge les annonces,
y compris celles créées depuis l’application.

La vitrine récupère les changements à son prochain rafraîchissement ; le jeu les
affiche à son prochain chargement des annonces. Masquer retire le contenu des deux
listes publiques, sans pouvoir rappeler des emails déjà envoyés.

## Utilisation

Les annonces servent aux mises à jour, aux événements à venir et aux nouveautés
de Mordeviel. Dans Administration → Publications, rédiger une annonce ou une FAQ.
Le formulaire conserve automatiquement le brouillon sur l’appareil, sans rien
publier. Une fermeture par Retour, clic extérieur ou bouton Fermer conserve la
saisie. Les modifications d’une publication existante restent privées jusqu’à
« Enregistrer dans le jeu ». Un échec réseau conserve le brouillon.

Les brouillons sont stockés via Flutter Secure Storage, séparés par serveur,
compte administrateur et publication. Les nouvelles offres de boutique et leurs
modifications ont également un brouillon. Ils ne sont pas synchronisés entre
appareils. Si le stockage local de l’éditeur d’annonce est indisponible, le message
indique que le brouillon est conservé uniquement pour la session.

Après publication réussie, le brouillon correspondant est supprimé. L’éditeur
d’annonce propose aussi un effacement explicite, avec confirmation.

## Annonces sur la vitrine

La section `/#annonces` lit `/community/info`, comme le jeu. Elle présente les
annonces publiques, récentes en premier, trois par trois, avec leur date de
publication et un aperçu du texte. Les textes longs sont dépliables.
Les FAQ, les brouillons et les publications masquées ne sont pas affichés.
La page se rafraîchit chaque minute lorsqu’elle est visible ; un bouton permet
une actualisation immédiate. Les données ne sont pas mises en cache.
Les textes sont affichés comme texte brut, sans interprétation de HTML.

## Envoi par email

Publier dans le jeu n’envoie aucun email automatiquement. Sur une annonce déjà
publiée, le bouton d’envoi/suivi des emails affiche les compteurs et demande
confirmation avant de mettre les envois en file. Une FAQ ou une annonce masquée
ne peut pas être envoyée.

Le message reprend le thème des relances : bleu nuit, or, logo et signature.
Il contient le titre et le texte de l’annonce, un lien vers les annonces de la
vitrine et une désinscription. Il utilise le SMTP déjà configuré.

Seuls les comptes non bannis avec adresse vérifiée et abonnés aux emails de la
communauté sont sélectionnés. Les préférences, l’adresse et la visibilité de
l’annonce sont revérifiées juste avant l’envoi. Les annonces modifiées avant leur
envoi sont annulées dans la file : l’admin peut programmer la nouvelle version.
Une désinscription couvre les relances et les emails d’annonce, pas les codes de
sécurité du compte.

Chaque version titre/texte ne peut être programmée qu’une fois par annonce.
La file et cette protection sont persistantes. Les envois incertains ou échoués
ne sont pas relancés automatiquement. Le suivi distingue `pending`, `sending`,
`sent`, `failed` et `cancelled`. `sent` signifie accepté par le relais SMTP ; cela
ne prouve pas une réception dans la boîte du destinataire.

Le worker traite jusqu’à 100 destinataires par passage, toutes les 60 secondes,
indépendamment de la fréquence et de l’activation des relances hebdomadaires.

## Mise en service

Déployer les sources et réinstaller le backend dans l’environnement utilisé par
le service, puis redémarrer ce service (actuellement `legendeofwolf.service`
sur le serveur existant). Les tables de campagnes sont créées au démarrage.
Recompiler et installer l’application pour obtenir les brouillons et le bouton
email. La rubrique de la vitrine utilise le backend public existant.

Les tests de cette évolution utilisent du SMTP simulé et un aperçu local isolé :
aucune annonce réelle n’a été envoyée par email pendant le développement.
