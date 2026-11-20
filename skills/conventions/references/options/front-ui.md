# Option `front-ui` — bibliothèque d'interface du frontend Angular

Clé dans `.claude/stack.json` : `"conventions": { "front-ui": "<valeur>" }`. Sans frontend, l'option est ignorée.
Elle est appliquée par `/add-frontend` à la création de l'application, puis par `frontend-dev` à chaque écran.

## Valeur : primeng-bootstrap
- **PrimeNG** pour les composants (tableaux, formulaires, boutons, dialogues, toasts) et son thème (`@primeuix/themes`,
  preset `Aura` par défaut), **PrimeIcons** pour les icônes.
- **Bootstrap pour la mise en page uniquement** : `bootstrap-grid.min.css` et `bootstrap-utilities.min.css` dans les
  `styles` d'`angular.json` (grille, espacements, flex, affichage). **Ni** `bootstrap.min.css` complet (son reboot et ses
  composants entrent en conflit avec le thème PrimeNG), **ni** le JavaScript de Bootstrap.
- Un composant d'interface = un composant PrimeNG (`p-table`, `p-button`, `p-inputtext`, `p-password`, `p-toast`…) ;
  pas de composant Bootstrap (`.btn`, `.card`, `.modal`) ni de composant maison qui duplique PrimeNG.
- Versions : la version majeure de `primeng` suit celle d'Angular ; vérifier `npm view primeng@<majeure> peerDependencies`.
  L'installation (providers, animations, thème) suit la documentation officielle de la version installée
  (https://primeng.org/installation) : elle change d'une version majeure à l'autre.
- Notifications : `MessageService` + un seul `<p-toast />` dans le composant racine ; l'intercepteur d'erreurs l'utilise.
- Budget de taille : le thème PrimeNG fait dépasser le seuil d'avertissement par défaut du bundle initial (500 kB).
  `/add-frontend` le relève à 800 kB dans `angular.json` (budget `initial`, `maximumWarning`), sans toucher au seuil
  d'erreur : un avertissement permanent finirait par masquer un vrai problème.

## Valeur : material
- **Angular Material** (`ng add @angular/material`), thème Material 3 ; mise en page en CSS (flex, grid), sans Bootstrap.
- Notifications : `MatSnackBar`, appelé par l'intercepteur d'erreurs.

## Valeur : aucune
- CSS maison (SCSS par composant + `styles.scss` global avec variables). Aucune bibliothèque de composants.
- Notifications : un service `NotificationService` (signal de messages) et un composant d'affichage dans `shared/`.
