# Rejoindre par QR code

## Parcours

1. Le MDJ crée son salon sur le Wi-Fi commun.
2. Sur la carte, il touche **Inviter par QR code**. Le même QR est aussi affiché
   dans **Habitants et préparation**.
3. Le joueur ouvre **Jouer en local**, choisit son pseudo, puis touche
   **Scanner pour rejoindre** dans l’application Mordeviel.
4. Après lecture d’une invitation valide, l’adresse et le code sont remplis et
   la connexion démarre avec le pseudo du joueur. La caméra est libérée quand
   la page de scan se ferme.

S’il y a plusieurs adresses réseau, le MDJ sélectionne celle du Wi-Fi utilisé
par les joueurs. Une adresse `192.168.*` est proposée en premier lorsqu’elle
existe ; ce classement n’est pas une détection garantie du bon adaptateur.

Le QR contient une invitation `mordeviel://join` versionnée avec l’adresse IPv4,
le port et le code à six chiffres. Il ne contient aucun rôle, identifiant joueur
ou jeton de reprise. Chaque téléphone rejoint avec une identité distincte.
Un QR étranger, une version inconnue, une adresse mal formée ou des champs
ambigus sont refusés avant la connexion. Le serveur conserve ses contrôles
habituels : code, inscriptions ouvertes, capacité et pseudo.

## Plateformes et alternatives

- Scan intégré sur Android et iOS, avec demande d’autorisation caméra à
  l’ouverture de cet écran. Les messages restent en français en cas de refus.
- Sur Windows, le MDJ peut afficher son QR. Un joueur Windows peut utiliser
  **Coller le lien du salon** ou la saisie manuelle.
- **Copier le lien du salon** donne le même contenu que le QR. Aucun message
  n’est envoyé automatiquement à un autre service.
- Le scan se fait depuis Mordeviel. L’ouverture de l’application depuis la caméra
  système par un lien profond n’est pas intégrée à cette étape.
- Le lecteur Android est embarqué pour fonctionner sans téléchargement pendant
  la partie. Le QR ne connecte pas automatiquement les appareils au Wi-Fi.

## Validation et installation

Les tests couvrent l’invitation, le QR affiché, le choix de l’adresse, le lien
collé et l’annulation. `packages/local_host/tool/qr_join_smoke.dart` vérifie que
deux joueurs rejoignent avec des identités distinctes puis se déclarent prêts.

Le lecteur caméra natif reste à vérifier sur téléphone après reconstruction et
redémarrage complet de l’application. Les autorisations Android/iOS sont ajoutées.
Un simple rechargement à chaud ne charge pas un nouveau plugin natif.
