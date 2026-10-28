# Vérification avant prochaine mise à jour — 28 octobre 2026

Vérification locale réalisée sans APK, connexion SSH ni email réel.

| Point | Résultat |
|---|---|
| Ambiance Horreur | Brume et passages de chauves-souris ; hibou perché puis vol vers la caméra : scénario de nuit exécuté par test de widgets. Les décors ne bloquent pas les clics. Pause, journée, arrière-plan et préférence de frayeurs conditionnent les effets. Les sons sont coupés avec les préférences audio ; en local seul le MDJ diffuse le son, tandis que les participants en ligne peuvent l’entendre. |
| Cartes | 20 illustrations par thème : 18 rôles, Maire et variante Villageoise. Présence des fichiers Classique, Intense et Horreur contrôlée. Les huit sentences Horreur correspondent toujours aux fichiers utilisateur. |
| Dashboard | Accès aux actions protégé par la dépendance administrateur côté API. Les tests refusent les comptes ordinaires. Maintenance, modération, support, offres, vitrine, téléchargements, collection, restrictions, bonus, essais et programmation des relances sont couverts par les tests correspondants. Les paiements réels restent désactivés. |
| Stickers | 17 stickers dans le catalogue commun. Envoi et lecture depuis un autre compte communauté vérifiés ; identifiant inconnu refusé. Sélecteur et affichage branchés dans la communauté et les discussions du village. Pack à télécharger, ensuite utilisable hors connexion. |
| Relances | Fréquence initiale de 7 jours, réglable de 1 à 90 jours. Test SMTP simulé : échéance, changement de fréquence, rotation des phrases, HTML et texte, désinscription, exclusion des comptes bannis/non vérifiés, suspension et échec d’envoi sans doublon. Le scheduler démarre avec FastAPI ; aucun cron supplémentaire requis. |
| Amis et salons | Demande, acceptation, refus, blocage, badges et confidentialité ; invitation de salon, acceptation à la connexion, refus et historique après fermeture. Test d’intégration avec le vrai moteur Dart. Les statistiques et identités sont contrôlées côté serveur. |

Les 12 packs contiennent 339 fichiers : tailles et empreintes SHA-256 vérifiées sans erreur. Les 286 fichiers WAV sont décodables et non vides. Pour l’Horreur, télécharger les packs de cartes, village et ambiance ; les stickers ont leur propre pack.

Validation : 190 tests Flutter de la suite complète, puis les 2 nouveaux contrôles Horreur ; 31 tests backend de la suite complète, puis les nouveaux tests des relances et stickers. Trois scénarios réseau réels supplémentaires passent : quatre joueurs simultanés avec contrôles de présence, nuit avec secrets/chat/potions/tir/victoire, jour avec chat/votes/reconnexion/élimination et passage à la nuit suivante. Analyse statique sans erreur.

Limites de cette vérification : aucune preuve d’envoi SMTP réel sur Contabo, de réception en boîte de messagerie, d’écoute sur haut-parleur physique ou d’affichage des notifications par Android en arrière-plan. Les tâches Android peuvent être retardées par le système. Ces points demandent un essai après mise à jour du serveur et installation de l’application sur les appareils ; ils ne sont pas présentés comme validés par les tests locaux.
