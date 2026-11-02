# Immersion et vocal — bilan de l'intégration locale

2 novembre 2026 — Roland DJAGBA Alias Logan, by Logan R.D.

Les sept lots du [plan](plan-immersion-et-vocal.md) possèdent maintenant leur intégration locale. Ce bilan distingue le code et les contrôles réalisés de la validation sur téléphones et du déploiement du service média, encore à effectuer par Logan.

## Cartes et sensations

- Maintien sur une carte couverte : un coin laisse apparaître une partie du recto. Relâchement, annulation ou passage en arrière-plan masquent immédiatement le coup d'œil. Le titre reste « Ma carte secrète » et le contenu aperçu est exclu de la sémantique du dos couvert.
- Inclinaison au doigt et retour amorti par ressort. Les boutons de consultation et le glissement de fermeture restent disponibles. Le retournement utilise un ressort pour passer entre l'illustration et les règles.
- Reflet discret Intense et traitement lumineux Horreur dans la consultation des cartes. La finition correspond à l'apparence individuelle, y compris en partie Mixte. Elle ne définit pas la rareté à partir du rôle.
- Son de manipulation générique de 0,19 seconde, créé par `tools/audio/create_card_foley.py`, environ 9 Kio embarqués. Il ne révèle aucun rôle et respecte les sons coupés et la scène silencieuse des participants locaux.
- Vibrations réglables sur les cartes, les sélections de maison et l'annonce d'une élimination. Les griffures, impacts, poison, découpe et perte de la fonction de Maire conservent leur logique.
- Les réglages « Vibrations des interactions », « Bruitages des cartes » et « Effets visuels légers » sont enregistrés sur l'appareil dans « Ambiance et immersion ». Le mode léger est propagé dans l'application avec la réduction des animations du système.

Le gyroscope reste reporté comme prévu au cadrage initial. Aucun nouveau bruitage distinct de découverte de rôle n'est diffusé publiquement. Aucune dissolution générique ne remplace les morts propres à chaque cause.

## Village et ambiance

Le [lot 1](immersion-lot-1.md) conserve le lieu observé à la rotation et au rafraîchissement. Zoom et déplacements partagent une caméra cohérente. Le défilement de la page est suspendu pendant la manipulation du terrain et revient au retrait du dernier doigt.

Les maisons vivantes disposent d'une faible lueur nocturne et de fumées limitées de cheminées. Les effets dépendent des emplacements publics, jamais des pouvoirs ou cibles secrètes. Pause, arrière-plan et réduction des animations conditionnent leur animation.

Le hibou possède un point d'ancrage dans le décor, transformé avec la caméra. Son approche suit une courbe de Bézier, avec inclinaison, battement suggéré par transformation des ailes, accélération de profondeur, flou bref au premier plan et trajet de retour. Il utilise l'illustration déjà installée dans le pack Horreur : il ne s'agit pas d'un modèle 3D articulé ni d'une nouvelle séquence d'images générées. Les chauves-souris, hululements et rires existants sont conservés. Le mode léger ou les frayeurs désactivées neutralisent les surprises concernées.

## Réactions et grimoire

Le bouton « Réagir sur ma maison » ouvre le pack de stickers existant. Un sticker flotte quatre secondes au-dessus de la maison. Une seule réaction est conservée par auteur et le serveur impose cinq secondes entre deux envois. Un pictogramme de remplacement reste lisible pendant la récupération d’une image de sticker manquante. Les réactions de la meute restent dans les vues privées autorisées pendant son appel. Les joueurs éliminés ne peuvent pas en envoyer aux vivants. Une réaction ne devient pas une sélection de pouvoir ni une entrée de l'historique final.

L'historique final possède une présentation de grimoire, des chapitres filtrables par manche, les transitions jour/nuit et les actions détaillées déjà enregistrées. Le détail secret n'est pas rendu public avant la fin.

Le conseil conserve son champ et son focus lorsque les contraintes changent. Sur les petits écrans et avec le clavier, le compositeur devient plus compact et peut défiler dans sa propre zone plutôt que déborder.

## Vocal

Le client Flutter intègre le SDK LiveKit, avec transport audio distinct des messages du jeu. Le serveur utilise les droits produits par Dart : phase, camp actuel, état vivant/éliminé et restrictions du MDJ. Les bots ne reçoivent pas de session vocale. Aucun accès au microphone n'est demandé avant une action explicite pour parler.

Micro fermé au départ, maintien pour parler, relâchement pour couper et cadenas facultatif. Le MDJ peut activer/désactiver le vocal, fermer la parole et rendre individuellement muet un joueur. Le changement de phase, l'arrière-plan et le départ coupent l'émission ; revenir dans l'application ne rouvre pas automatiquement le microphone. Une autorisation native qui se termine après le relâchement ne doit pas lancer une publication tardive.

Seuls les destinataires du canal reçoivent ses indicateurs de parole sur les maisons. Une panne du vocal affiche une explication et conserve le jeu écrit. Les anciens services sans cette capacité donnent un message de mise à jour au MDJ ; les réactions ne sont pas proposées si le moteur ne les annonce pas.

FastAPI délivre des jetons audio de courte durée, limités à un canal, au microphone et à la session privée du salon. Les changements de droits retirent les anciens canaux. La création automatique de salles LiveKit est désactivée. Les annonces automatiques suspendent temporairement la publication et l'ambiance musicale baisse pendant les échanges vocaux.

L'installation est prête dans [le guide Contabo](deploiement-vocal.md), avec script de génération des clés, Docker Compose et fragment Nginx pour le domaine HTTPS existant. Le mode local conserve les échanges dans la même pièce et la diffusion d'ambiance chez le MDJ.

## Packs et poids

Les nouveaux mouvements et lumières sont calculés dans Flutter et réutilisent les images installées. Aucun pack n'a besoin d'être republié pour ces seules modifications ; les téléchargements existants et leurs versions sont conservés. La voix classique et les extraits de test restent embarqués comme auparavant.

Le SDK WebRTC ajoute des dépendances et des bibliothèques natives. Le poids final de l'APK doit donc être mesuré lors du build de Logan ; les effets procéduraux n'ajoutent pas de grandes vidéos ou de nouvelles collections d'images. Un APK par architecture peut être produit avec `flutter build apk --release --split-per-abi` si Logan souhaite distribuer plusieurs fichiers adaptés aux appareils ; un App Bundle permet la distribution par architecture via Google Play.

## Validation réalisée

- **91 tests Flutter ciblés réussis** : interactions, cartes, audio, réactions, droits du moteur, grimoire, trois terrains, conseil, clavier et contrôles vocaux, accueil et ouverture. Les appels média sont simulés dans ces tests.
- **18 tests backend réussis**, dont droits vocaux et révocation, concurrence de changement de phase, préparation des clés, narration, packs, vitrine, bots et parties avec le véritable moteur Dart. L'API de contrôle LiveKit est simulée ; ces tests ne prétendent pas transmettre de l'audio réel.
- Analyse statique Flutter/Dart et Ruff des fichiers concernés sans anomalie lors des derniers contrôles. Configuration plist du microphone iOS et structure Docker Compose vérifiées.
- Captures de l'interface vocale portrait et paysage inspectées. Tests supplémentaires avec clavier ouvert, relâchement pendant autorisation du micro et annulation multitouch.

Les tests Python signalent encore un avertissement de dépréciation Starlette/httpx et, dans une exécution groupée sous Windows, des avertissements de fermeture de pipes asyncio. Les assertions de ces 18 scénarios ont réussi. Les corrections du parcours de connexion à la communauté qui étaient déjà présentes dans le dossier ne font pas partie de ce bilan.

## Reste à valider avec Logan

- Build APK par Logan, rendu et fluidité sur les téléphones utilisés pour jouer.
- Installation de LiveKit et du routage Nginx sur Contabo avec le guide fourni. Aucune connexion SSH ou modification du serveur distant n'a été effectuée ici.
- Écoute réelle entre deux réseaux, autorisations natives, haut-parleur/casque, écho, qualité audio et tenue sous charge. Le moteur Docker local n'était pas démarré et aucun service média réel n'a été lancé pendant cette intégration.

Les changements de pouvoirs Intense/Horreur restent une autre mise à jour, à discuter avec Logan.
