# Comptes, profils et vérification par email

## Règle actuelle

Tous les nouveaux comptes, administrateurs compris, doivent vérifier leur adresse
email avant d'utiliser la communauté. L'inscription demande pseudo, email et mot
de passe. Un code à six chiffres est envoyé par SMTP ; l'app demande de le saisir.
Les comptes existants sans adresse sont dirigés vers cet écran à leur prochaine
connexion, après saisie correcte de leur mot de passe. Ils ne sont pas marqués
vérifiés automatiquement. Les inscriptions publiques n'attribuent aucun rôle admin.

Le profil présente le pseudo, le rôle, la certification administrative, l'email
vérifié, l'état du compte et les restrictions éventuelles. L'historique provient
uniquement des lignes d'achat du compte connecté ; il est vide tant qu'aucun achat
n'a été effectué. Les paiements restent désactivés et aucun achat fictif n'est créé.

## Connexion conservée pendant 24 heures

Après une authentification et la vérification email, l'application conserve le
jeton dans le stockage sécurisé de l'appareil. Quitter la communauté, revenir à
l'accueil ou fermer puis rouvrir l'application ne demande pas une nouvelle
connexion tant que cette session reste valide. Aucun mot de passe ni droit
administrateur n'est enregistré dans ce cache ; les droits sont relus du serveur.

Les nouveaux jetons expirent 24 heures après leur création. Ouvrir la communauté
ne repousse pas cette échéance. L'API renvoie `expires_at` à la connexion ; l'app
respecte cette date, avec une limite locale de 24 heures pour les anciens serveurs.
À expiration, déconnexion volontaire, invalidation serveur, bannissement,
changement de mot de passe ou suppression de compte, le jeton local est effacé.
Une panne réseau temporaire conserve la session afin de permettre une reprise.

## Changer ou récupérer un mot de passe

Dans Connexion → Mot de passe oublié, ou depuis le profil :

1. Saisir le pseudo ou l'email.
2. Recevoir le code à l'adresse déjà associée au compte.
3. Saisir ce code, le nouveau mot de passe et sa confirmation.
4. Se reconnecter : toutes les anciennes sessions ont été invalidées.

Aucune exception n'existe pour un joueur ou un administrateur. Le code expire
après dix minutes, se bloque après cinq essais incorrects et ne sert qu'une fois.
Les codes ne sont ni renvoyés dans les réponses API ni affichés dans les logs.
Les demandes de récupération renvoient un message générique pour ne pas indiquer
publiquement si un pseudo ou un email possède un compte. Le changement direct
avec l'ancien mot de passe seul est également refusé : l'email est obligatoire.
Les adresses ne sont pas exposées dans le chat, le catalogue ou les invitations.

## SMTP dans le .env du serveur

Copier les noms présents dans backend/.env.example et renseigner dans le fichier
privé backend/.env, sans le committer :

```dotenv
LE_LOUP_SMTP_HOST=smtp.votre-fournisseur.fr
LE_LOUP_SMTP_PORT=587
SMTP_USE_TLS=true
LE_LOUP_SMTP_USERNAME=votre-identifiant
LE_LOUP_SMTP_PASSWORD=votre-secret
LE_LOUP_SMTP_FROM=contact@votre-domaine.fr
```

Le port 587 utilise STARTTLS ; le port 465 utilise TLS implicite. Le certificat
du serveur est vérifié. Aucun envoi SMTP en clair n'est prévu.
`SMTP_USE_TLS=true` est obligatoire ; si cette option est désactivée, l'envoi
est refusé au lieu de transmettre les identifiants et les codes sans chiffrement.
L'expéditeur doit être autorisé chez le fournisseur choisi. Configurer ensuite
SPF/DKIM/DMARC avec ce fournisseur pour la délivrabilité.

FastAPI charge désormais backend/.env automatiquement au démarrage, sans écraser
les variables déjà définies dans le service. L'option explicite reste possible :

```powershell
backend/.venv/Scripts/python.exe -m uvicorn le_loup_api.main:app --env-file backend/.env --host 0.0.0.0 --port 8000
```

Sur Contabo, utiliser le chemin Linux de l'environnement Python et du .env.
Sans SMTP configuré ou si l'envoi échoue, le backend refuse l'opération avec un
message d'indisponibilité ; il ne prétend pas avoir envoyé un email.
Un compte créé mais non confirmé peut reprendre la vérification en se connectant
avec son mot de passe et en demandant un nouveau code.

Pour le premier administrateur :

```powershell
backend/.venv/Scripts/python.exe -m le_loup_api.create_admin --nickname "Logan R.D" --email "votre-adresse@votre-domaine.fr"
```

La commande demande le mot de passe en privé. La première connexion dans l'app
demande ensuite la vérification par email. Pour un ancien compte dépourvu d'email
et dont le mot de passe a été perdu, une intervention manuelle de l'exploitant
reste nécessaire : aucun pseudo seul ne permet d'en prendre possession.

Les tests utilisent une boîte d'envoi simulée ; aucun email réel n'est envoyé.
La réception réelle sera à vérifier après configuration SMTP sur le serveur.
