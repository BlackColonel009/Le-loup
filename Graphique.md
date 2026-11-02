# 🌑 Mordeviel - Plan d'Attaque "Game Feel & Réalisme"

> Plan de réalisation adapté au système actuel, préparé le 1er novembre 2026 :
> [Immersion et vocal — lots, architecture et critères de validation](docs/plan-immersion-et-vocal.md).
> Les propositions ci-dessous sont conservées comme document source ; leurs cases ne constituent pas un état vérifié de l'application.

Ce document trace les étapes d'amélioration de l'immersion et de la qualité visuelle/tactile des cartes et du village.

## 📌 Phase 1 : La Physique & L'Interaction (Le "Toucher")
*Objectif : Donner du poids et de la consistance aux objets virtuels.*

- [ ] **Haptic Feedback (Vibrations)**
    - Micro-vibration lors du retournement de la carte.
    - Vibration sourde lors d'une élimination (griffures).
    - Retour léger lors de la sélection d'une maison dans le village.
- [ ] **Spring Animations (Physique des ressorts)**
    - Remplacer les courbes de rotation linéaires par des simulations de ressort pour éviter les arrêts brusques.
- [ ] **Le Geste "Peek" (Coup d'œil)**
    - Permettre de soulever un coin de la carte au toucher long pour voir son rôle sans la retourner entièrement.
- [ ] **Perspective 3D Interactive**
    - Inclinaison de la carte en fonction de la position du doigt ou du gyroscope.

## ✨ Phase 2 : Le Visuel & Les Shaders (Le "Look")
*Objectif : Ajouter des effets de lumière et de matière haut de gamme.*

- [ ] **Effet Holo/Foil (Brillance)**
    - Ajouter un reflet arc-en-ciel dynamique sur les cartes rares (Loups, Voyante).
- [ ] **Shader de Dissolution (Mort)**
    - Remplacer la disparition des cartes par un effet de combustion ou de poussière qui s'envole.
- [ ] **Ambiance Lumineuse du Village**
    - Transitions fluides (渐变) entre le jour et la nuit sur la carte interactive.

## 🔊 Phase 3 : L'Audio Contextuel (L' "Ouïe")
*Objectif : Renforcer l'action par une signature sonore.*

- [ ] **Bruitages de cartes**
    - Sons de manipulation de papier/carton rigide.
- [ ] **Identité sonore des rôles**
    - Un son court et thématique lors de la découverte du rôle secret.

---

## 🌌 Phase 4 : Immersion Atmosphérique (Le "Monde")
*Objectif : Transformer l'UI en un univers vivant.*

- [ ] **Météo Dynamique** : Brume nocturne, particules de feu follet, cycle de lumière progressif.
- [ ] **Vie du Village** : Cheminées actives, animations de fenêtres et états de dégradation des maisons.
- [ ] **Focus Visuel** : Gestion de la profondeur de champ (Depth of Field) lors des interactions.

## 🏆 Phase 5 : Personnalisation (Le "Prestige")
*Objectif : Valoriser le joueur et préparer l'évolution Premium.*


- [ ] **Réactions Expressives** : Système d'emotes flottantes pour interagir sans parler.

## 🧠 Phase 6 : Méta-jeu et Feedback Social
*Objectif : Rendre les intentions des joueurs perceptibles.*

- [ ] **Indices visuels d'activité** : Halo discret sur les maisons des joueurs actifs ou en réflexion.
- [ ] **Grimoire Narratif** : Résumé des événements de la partie sous forme de journal animé.
- [ ] **Spatialisation** : Cohérence entre la position visuelle sur la map et les retours audio/visuels.
Au lieu de faire un appel vocal je préfere une icone genre tu maintient ou tu peux le bloquer qui permettra de parler directement dans le jeu et quan tu relache il devient une icone muette. et sur la map il est visible sur une maison quand quelqu'un parle.

## phase 7: Map qui se plante quand on la touche
* Adapter la map dans son écran pour qu'on puisse zoomer avec les doigts, réduire et en format paysage remplir bien son cadre et permettre que le joueur puisse la visiter dans tous les recoins sans plantage.

## 🦉 Phase 8 : Animations Narratives (Le vol du Hibou)
*Objectif : Rendre les transitions de jeu organiques et impressionnantes.*

- [ ] **Vol en Courbe de Bézier** : Remplacer le mouvement linéaire par une trajectoire courbe et naturelle.
- [ ] **Perspective Z-Axis** : Augmenter la taille de l'oiseau de façon exponentielle à l'approche de l'écran pour simuler la profondeur.
- [ ] **Inclinaison Dynamique (Banking)** : Incliner le sprite du hibou en fonction de la direction de son virage.
- [ ] **Effet de "Near-Clipping"** : Ajouter un flou de mouvement (Motion Blur) et un léger tremblement de caméra quand il passe au premier plan.
  ???? Pourquoi ton hibou actuel ne semble pas réel ?C'est souvent dû au "scaling" linéaire. Dans Flutter, si tu passes d'une taille 50 à 500 en 2 secondes de façon constante, l'œil humain perçoit cela comme un simple zoom 2D.L'astuce de pro : Pour simuler la 3D, le hibou doit rester petit pendant 70% du temps, puis sa taille doit exploser sur les 30% restants de l'animation. C'est ce qu'on appelle une courbe d'animation "EaseInExpo".




## 🛠️ Journal des modifications
*Note : Inscrire ici les dates et les fichiers modifiés lors des interventions.*

- **[Date]** : Initialisation du plan d'attaque.
- **1er novembre 2026** : caméra, zoom, gestes et rotation du village — voir `docs/immersion-lot-1.md`.
- **2 novembre 2026** : intégration locale des cartes interactives, réglages, ambiance, réactions, grimoire et vocal ; voir [le bilan et les validations restantes](docs/immersion-livraison-complete.md).
