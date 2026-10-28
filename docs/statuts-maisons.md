# Ombres de statut des maisons

- Avant la distribution (`lobby`, sans partie), une ombre verte diffuse se trouve
  au sol sous chaque maison dont le joueur est prêt. Sans confirmation, aucune
  ombre de statut n’est dessinée.
- Dès la distribution, toutes les ombres vertes disparaissent, même si le salon
  conserve un ancien indicateur `ready` dans ses données.
- Pendant la partie et à sa fin, une maison de joueur absent de `alive_ids`
  reçoit une ombre rouge au sol. Le sprite détruit et le fantôme sont conservés.
- Les thèmes Classique et Intense partagent ces règles. Le halo est sous la
  maison, jamais autour de toute la carte. Il ne capte aucun geste. La protection
  dorée du Salvateur reste un effet distinct.

Les changements proviennent des états autoritaires du salon. Un joueur ne
choisit pas sa couleur lui-même. Le statut prêt est aussi annoncé aux lecteurs
d’écran. Aucun nouvel asset ni effet sonore n’est nécessaire.

Tests : salon prêt/non prêt, disparition au début, élimination et deux thèmes.
Captures facultatives avec `CAPTURE_HOUSE_STATUS`, sous `build/previews/`.
