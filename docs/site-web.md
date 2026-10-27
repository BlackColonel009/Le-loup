# Vitrine Legende of Wolf

Le site est livré dans le paquet FastAPI : aucun serveur Node ni compilation
web supplémentaire. Nginx continue à transmettre les requêtes à 127.0.0.1:8090.
L'application mobile reste nécessaire pour jouer ; la vitrine n'est pas un client
de partie dans le navigateur.

## Pages

- `/` : présentation, captures de l'interface dans des cadres de téléphone,
  éditions Classique / Intense Premium / Horreur et galerie dynamique.
- `/confidentialite` : politique de confidentialité.
- `/suppression-compte` : effacement du compte vérifié par email.
- `/support` : aide et contact.
- `/administration` : connexion administrateur et gestion des cartes du site.

Les pages et les ressources sont dans `backend/src/le_loup_api/web`.
Les captures proviennent du rendu des vrais widgets Flutter avec des données de
démonstration ; les cadres de téléphone sont illustratifs, pas des photographies
d'appareils. Les visuels Horreur pourront être ajoutés via le dashboard.

## Aperçu sur Windows

Depuis la racine du dépôt :

```powershell
backend/.venv/Scripts/python.exe -m pip install -e ./backend
backend/.venv/Scripts/python.exe -m uvicorn le_loup_api.main:app --host 127.0.0.1 --port 8090
```

Ouvrir http://127.0.0.1:8090. Pour isoler les données d'essai, définir d'abord
`LE_LOUP_COMMUNITY_DB` vers une base temporaire, sans toucher à la base réelle.

## Mise en place sur Contabo

Après commit et push des modifications du poste local, exécuter sur le serveur :

```bash
cd /var/www/Le-loup
git pull --ff-only
backend/venv/bin/python -m pip install -e ./backend
```

Configurer dans `backend/.env` :

```dotenv
LE_LOUP_PUBLIC_SUPPORT_EMAIL=adresse-publique-du-support
```

Remplacer par une vraie adresse. Cette adresse est rendue publique ; elle est
indépendante des identifiants SMTP. Les variables SMTP existantes servent à
envoyer les codes de suppression ; aucun nouveau prestataire n'est requis.

Vérifier les coordonnées de l'exploitant, le prestataire SMTP, les politiques de
sauvegarde et de conservation des journaux avant de publier la politique comme
document définitif. Le texte décrit le comportement actuel de la base active et
ne promet pas l'effacement automatique des journaux ni des sauvegardes.

Dans le bloc `server` HTTPS du site Nginx, ajouter la directive suivante pour
autoriser les images du dashboard (JSON base64, image source de 4 Mo maximum) :

```nginx
client_max_body_size 8m;
```

Puis, en dehors d'une partie en cours :

```bash
sudo nginx -t && sudo systemctl reload nginx
sudo systemctl restart legendeofwolf
curl -fsS https://legendeofwolf.newtechnologiestg.com/health
curl -fsS https://legendeofwolf.newtechnologiestg.com/gallery/cards
```

Le redémarrage termine les salons en mémoire. Les comptes, la galerie et les
visuels téléversés sont persistants.

## Administrer la galerie

### Téléchargement de l'APK

Dans `/administration`, la section « Le lien de téléchargement » permet de
coller un lien de partage MEGA complet, avec sa clé après `#`, d'indiquer une
version et d'activer les boutons publics. Le bouton principal d'accueil et celui
de la section téléchargement ouvrent ce lien dans un nouvel onglet. Aucun APK
n'est stocké dans le dépôt ni sur le backend.

La configuration est persistante en base SQLite et réservée aux administrateurs
avec email vérifié. Un lien HTTPS est requis ; le serveur ne visite pas le lien.
Décochez l'activation pour suspendre les téléchargements en conservant le lien
en brouillon. Sans lien actif, le site indique que le téléchargement est à venir.
Une nouvelle version peut être publiée en remplaçant le lien, sans reconstruire
le site ni l'application. Tester que le partage MEGA est accessible à une
personne non connectée avant de l'activer.

### Cartes présentées

Ouvrir `https://legendeofwolf.newtechnologiestg.com/administration` et se connecter
avec un compte administrateur du backend. Les comptes joueurs ne peuvent pas
gérer les cartes. Si nécessaire, créer le compte depuis le serveur selon
`docs/administration.md` ; aucun compte ni mot de passe prédéfini n'est ajouté.

Le dashboard permet d'ajouter, modifier, ordonner, masquer et retirer une carte,
avec son édition, son rôle, son texte et son visuel. Les changements concernent
uniquement la vitrine : ils ne changent pas les cartes ni les pouvoirs dans
l'application Flutter. Les sessions web restent en mémoire et sont perdues au
rechargement de la page ; les accès API restent contrôlés côté serveur.

Les cartes sont dans la table `site_cards` de la base communauté. Les images
téléversées sont stockées dans `site-uploads/` à côté de cette base, donc par
défaut `backend/data/site-uploads/`. Sauvegarder ensemble la base et ce dossier.
Avec le service existant, le compte `legendeofwolf` doit avoir accès en écriture
au dossier de données. Ne pas stocker les téléversements dans le code Git.

Les images acceptées sont PNG, JPEG ou WebP, jusqu'à 4 Mo et 4096 pixels par côté.
Elles sont décodées puis réencodées en WebP, sans métadonnées. Les SVG sont refusés.

## Suppression de compte

1. Saisie de l'adresse associée au compte, sans connexion préalable.
2. Réponse générique, sans révéler si le compte existe.
3. Envoi d'un code temporaire à l'adresse du compte, valable dix minutes.
4. Code + confirmation explicite : suppression immédiate de la base active.

Le compte, les sessions, les codes, les messages, les signalements liés, les
tickets et leurs réponses, l'historique d'achats et les entrées d'audit relatives
au compte sont effacés dans une transaction. Les autres utilisateurs restent
intacts. Le parcours fonctionne aussi pour un compte banni ou restreint.
Les codes d'inscription/récupération ne peuvent pas servir à supprimer un compte.
Après cinq mauvais essais, il faut demander un nouveau code.

L'application propose le même parcours dans Communauté → Mon profil → Supprimer
mon compte et mes données. Quitter une partie reste une action distincte : les
salons actuels ne sont pas liés aux comptes communauté.

Pour Play Console, utiliser les pages publiques `/confidentialite` et
`/suppression-compte` après déploiement. Les autres exigences de publication
(signature, déclarations des données, tests, modération) restent à préparer.

## Vérification

Les tests de `backend/tests/test_website.py` utilisent des bases temporaires et
des emails simulés. Ils vérifient l'accès public, l'effacement et l'isolation des
comptes, l'expiration et l'usage unique des codes, les permissions administrateur
et le cycle de vie des images de la galerie. Aucun email réel n'est envoyé.
