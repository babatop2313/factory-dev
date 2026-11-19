---
description: Crée le frontend Angular du projet (nom et version d'Angular au choix), installe la bibliothèque d'interface de l'option front-ui, le lint et le proxy vers le backend, pose la structure core/shared/features, puis déclare le dossier dans factory.json.
argument-hint: [dossier, ex. frontend]
---

Dossier souhaité (facultatif) : $ARGUMENTS

Tu crées le frontend Angular du projet en suivant le skill `angular-conventions` (lis-le en entier d'abord) et l'option
`front-ui` du skill `conventions`. Tu ne modifies jamais toi-même `.claude/factory.json` : c'est le script du kit qui y
déclare le dossier (étape 7). Toute installation de paquet passe par npm, avec mon accord.

1. **Préconditions**
   - Le début de session annonce `<frontend> = aucun` (ou un dossier qui n'existe pas encore). Si un frontend existe
     déjà, arrête-toi : cette commande ne le recrée pas.
   - `node -v` et `npm -v` : sans Node.js, arrête-toi et indique-moi comment l'installer (version LTS, nodejs.org).
   - Mode copie (`<kit>` = `.claude`) : le script du kit n'est pas dans le projet ; à l'étape 7, donne-moi la commande
     à lancer depuis le dépôt du kit au lieu de la lancer.

2. **Versions disponibles** (aucune écriture) :
   `npm view @angular/cli dist-tags --json` (versions `latest`, `next`…) et, pour la version proposée,
   `npm view @angular/cli@<version> engines.node` (version de Node exigée).

3. **Questions**, en une seule fois (outil de questions à choix s'il est disponible) :
   - **Dossier** du frontend : `$ARGUMENTS` ou `frontend` par défaut ; chemin relatif au projet, sans `..`.
   - **Nom de l'application** (nom du projet Angular, `kebab-case`) : par défaut le nom du dossier.
   - **Version d'Angular** : `latest` par défaut (rappelle son numéro), ou une version majeure précise (ex. `20`).
     Signale une incompatibilité avec la version de Node installée.
   - **Bibliothèque d'interface** : la valeur effective de `front-ui` (annoncée au démarrage, profil ou projet), à confirmer.
     Une autre valeur se règle dans `.claude/stack.json` (avec mon accord) avant de continuer.

4. **Récapitulatif** des choix et des commandes que tu vas lancer. **Attends mon accord explicite.**

5. **Création**, depuis la racine du projet :
   `npx -y @angular/cli@<version> new <nom> --directory <dossier> --routing --style=scss --ssr=false --skip-git --defaults --interactive=false`
   Si la version refuse une option, lis `npx -y @angular/cli@<version> new --help` et adapte la commande (sans ajouter
   d'option que je n'ai pas validée) ; dis-moi ce que tu as changé.
   Ensuite, depuis `<dossier>` :
   - **Lint** : `npx ng add angular-eslint@<majeure d'Angular> --skip-confirmation` (le script `lint` doit exister ensuite) ;
   - **Bibliothèque d'interface** : selon la section de `front-ui` retenue (versions compatibles avec la version
     majeure d'Angular ; installation selon la documentation officielle de la version installée) ;
   - **Proxy** : `proxy.conf.json` (`"/api"` → `http://localhost:8080`, `"secure": false`) et
     `"proxyConfig": "proxy.conf.json"` dans les options de `serve` (développement) d'`angular.json`.

6. **Structure de base** (socle `angular-conventions`, sans écran métier) :
   - `src/app/core/http/problem-detail.ts` (modèle `ProblemDetail`) et `src/app/core/http/error.interceptor.ts`
     (notifications selon `front-ui`), enregistré dans `app.config.ts` avec `provideHttpClient(withInterceptors([...]))` ;
   - `src/app/core/layout/` : un en-tête minimal (nom de l'application), affiché par le composant racine avec
     `<router-outlet />` et, selon `front-ui`, le conteneur de notifications ;
   - dossiers `src/app/shared/` et `src/app/features/` (un `.gitkeep` chacun) ; page d'accueil générée par le CLI remplacée
     par une page simple ;
   - **pas d'authentification ni d'écran métier** : ils viennent par `/feature`, à partir du contrat d'API du backend.
   Vérifie : `npx ng build`, `npm run lint`, `npx ng test --watch=false` (dans le dossier du frontend). Tout doit passer.

7. **Déclaration du dossier** (le script n'accepte que si le champ `frontend` est absent ou `null`) :
   `bash "<kit>/tools/install.sh" . --mode plugin --frontend <dossier>`
   Puis lis `.claude/factory.json` (outil Read) et montre-moi le champ `frontend`.

8. **Clôture** : fichiers créés (résumé par dossier, pas la liste de `node_modules`), versions installées (Angular,
   bibliothèque d'interface, angular-eslint), résultats de build, lint et tests, puis la suite :
   1. relancer Claude (`/exit`, puis `claude`) : le début de session doit annoncer `<frontend> = <dossier>` ;
   2. lancer le backend, puis `npx ng serve` dans `<dossier>` et ouvrir http://localhost:4200 ;
   3. compléter `CLAUDE.md` (section Frontend : version, commandes `ng serve`, `ng test`, `ng build`) ;
   4. commiter dans une branche (ex. `chore/add-frontend`) : le dossier du frontend (sans `node_modules`, déjà ignoré
      par le `.gitignore` généré) — `.claude/factory.json` a été modifié par le script : ajoute-le aussi.

Ne commite rien et ne pousse rien sans mon accord.
