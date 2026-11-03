# Version installée et publication des mises à jour

La version du projet est `0.3.3+3` dans `apps/mordeviel/pubspec.yaml` : version publique `0.3.3`, numéro technique Android `3`. Le pied de l’accueil affiche la version du paquet effectivement installé grâce à `package_info_plus`, et non celle annoncée par le serveur.

## Publier la version suivante

1. Passer le projet à `0.3.4+4` avant de compiler le nouvel APK. Le numéro après `+` doit toujours être supérieur à celui de tous les APK déjà distribués. Si un build historique utilisait déjà un numéro supérieur, choisir un numéro supérieur à ce dernier.
2. Compiler et vérifier le nouvel APK, puis le déposer sur le service de téléchargement.
3. Dans l’administration du site, saisir `0.3.4`, renseigner le lien du nouvel APK et activer le téléchargement ; enregistrer.
4. Une application en `0.3.3` reçoit la demande de mise à jour. Une application en `0.3.4` ou dans une version plus récente ne la reçoit pas. Le numéro technique est également comparé si la version publiée contient explicitement un `+`.

Le contrôle Android se fait après la vidéo d’ouverture, au retour au premier plan et chaque minute pendant que l’application est active. Le contrôle est situé sur la route d’accueil : il n’interrompt pas une partie ouverte dans une autre route. Une publication n’est donc pas une notification instantanée poussée au téléphone ; elle est récupérée au prochain contrôle réussi.

L’écran de mise à jour affiche la version installée et la version disponible. Le téléchargement n’installe pas automatiquement l’APK et ne valide pas la mise à jour : Android doit réellement installer le nouveau paquet.

Changer le lien sans augmenter la version ne demande plus de réinstallation. Une erreur réseau initiale laisse le jeu local accessible ; une mise à jour déjà détectée reste affichée si une vérification échoue. Le lien APK ne concerne pas Windows ou iOS.

Les modifications du dépôt n’altèrent pas les APK déjà installés : il faut distribuer un nouveau build contenant le détecteur et le pied de page. L’administration seule ne change jamais la version embarquée dans un APK existant.
