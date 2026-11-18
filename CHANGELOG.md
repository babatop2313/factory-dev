# Changelog

## v4.1.2 — Le dossier `.claude/` ne se supprime plus en bloc
Rien à faire dans un projet existant : mettre à jour le plugin.

- `guard-bash` bloque la suppression du dossier `.claude/` entier ou de ses fichiers par motif (`git rm -r .claude`,
  `rm -rf .claude`, `Remove-Item -Recurse .claude`, `git rm .claude/*.json`…) : `factory.json`, `stack.json` et
  `settings.json` disparaissaient avec lui sans que la règle de verrou, qui cherche le nom `factory.json`, ne le voie.
  Supprimer un fichier précis reste possible (avec l'accord de l'humain).
- Constat sur Bibliothèque : les trois fichiers du projet supprimés et indexés deux fois, cause encore inconnue.

## v4.1.1 — Retours du premier essai de `/top-factory:init`
**À faire dans un projet existant** : si `.claude/factory.json` indique `"frontend": "frontend"` alors que le projet
n'a pas de frontend, remplacer à la main par `"frontend": null` (Claude ne modifie pas ce fichier).

- **Frontend absent** : sans frontend détecté ni demandé, `factory.json` indique `"frontend": null` au lieu d'une valeur
  par défaut silencieuse ; le démarrage annonce « aucun frontend ». `--frontend` accepte un dossier encore à créer et
  peut renseigner plus tard un frontend `null` (le backend, lui, doit exister).
- **Projet déjà initialisé** : `--detect` signale l'`ArchitectureTest` existant ; `/top-factory:init` ne propose alors pas
  `/init-architecture`, qui refuse en outre un module déjà présent (un module existant évolue par `/feature`).
- **Clôture d'init** : commit dans une branche partie de la branche d'intégration à jour, fichiers ajoutés explicitement,
  jamais `settings.local.json` ; Claude signale un index déjà chargé.
- Tests : 162 scénarios en mode copie, 165 en mode plugin.

## v4.1.0 — Top Factory : nouveau nom, commande init, dossiers configurables
**À faire dans un projet existant** (dans une branche dédiée, par exemple `chore/top-factory-v4.1.0`) :
1. Dans Claude Code, remplacer l'ancien plugin : `/plugin uninstall factory@factory-dev`, `/plugin marketplace remove factory-dev`,
   puis `/plugin marketplace add babatop2313/top-factory` et `/plugin install top-factory@top`. Relancer Claude.
2. `/top-factory:init` (mise à jour : aucune question sur l'architecture) : réécrit `.claude/settings.json`
   pour activer `top-factory@top` à la place de `factory@factory-dev`.
3. Rien à faire pour les dossiers si le backend s'appelle `backend/` et le frontend `frontend/` (valeurs par défaut).
   Sinon : `bash <kit>/tools/install.sh . --mode plugin --backend <dossier> [--frontend <dossier>]` ajoute les champs.

### Nouveau nom
- Plugin **`top-factory`**, marketplace **`top`**, dépôt `babatop2313/top-factory` (GitHub redirige l'ancienne adresse).
- Commandes : `/top-factory:feature`… ; annonces des hooks : `TOP FACTORY`.

### `/top-factory:init`
- Initialise un projet **depuis Claude** : détection, questions (architecture, branche, intégrations, dossiers),
  récapitulatif et accord, puis appel de `install.sh`. Toute l'écriture reste dans le script (réutilisable par d'autres outils).
- Sur un projet initialisé : mise à jour, sans question sur l'architecture.
- Mode plugin seulement : en mode copie, la commande s'appellerait `/init`, comme la commande intégrée de Claude Code.

### Dossiers backend et frontend configurables
- Nouveaux champs `backend` et `frontend` dans `.claude/factory.json` (défaut `backend`, `frontend` ; `.` = racine).
- `install.sh` les détecte (`pom.xml` Spring Boot, `angular.json`, profondeur 2, parent d'un multi-modules) ;
  options `--backend`, `--frontend`, `--detect`, `--integrations` ; refuse un chemin absolu ou avec `..`, et refuse
  de changer un dossier déjà déclaré. Les vérifications ont lieu avant toute écriture.
- `session-start` annonce `<backend>` et `<frontend>` et signale un backend introuvable ou invalide ; agents, commandes
  et règles utilisent `<backend>`/`<frontend>` ; les hooks lisent les valeurs via `lib.sh`.
- `post-edit-check` ne se désactive plus en silence : un backend introuvable est signalé.
- `check-references.sh` refuse `backend/` ou `frontend/` écrits en dur dans le kit.
- Limite : un seul backend par projet (plusieurs backends : évolution suivante).

### Projets sans factory
- Le plugin est activé pour tous les projets : sans `factory.json`, `session-start` affiche un message court
  (proposer `/top-factory:init`, sinon ignorer) au lieu d'imposer les règles ; la compilation automatique et le rappel
  `clean` ne s'appliquent pas. Les protections (`guard-bash`, `guard-files`, `guard-mcp-sql`) restent actives partout.

### Tests
- `test-hooks.sh` : 157 scénarios en mode copie, 160 en mode plugin (dossiers, backend à la racine, multi-modules,
  plusieurs backends, refus avant écriture, projet non initialisé, mode copie sans `init`).

## v4.0.0 — La factory devient un plugin Claude Code
**À faire dans un projet existant** (dans une branche dédiée) :
- **Passer au plugin (recommandé)** : dans Claude Code, `/plugin marketplace add babatop2313/factory-dev` puis
  `/plugin install factory@factory-dev` ; ensuite `bash factory-dev/tools/install.sh <projet> --mode plugin`.
  Le script retire de `.claude/` les fichiers copiés du kit, garde ceux propres au projet, et réécrit `settings.json`
  (permissions + activation du plugin, sans hooks). Commandes : `/factory:feature`, ou `/feature` sans conflit de nom.
- **Rester en mode copie** : `bash factory-dev/tools/install.sh <projet>` comme avant ; rien d'autre à faire.

### Plugin
- Le dépôt est un **plugin** (`.claude-plugin/plugin.json`, nom `factory`) et sa propre **marketplace**
  (`.claude-plugin/marketplace.json`, nom `factory-dev`).
- Nouvelle structure : `agents/`, `commands/`, `skills/`, `hooks/hooks.json` + `hooks/scripts/`, `rules/factory.md`,
  `templates/` (fichiers créés dans les projets). Il n'y a plus de dossier `.claude/` dans le dépôt du kit.
- **Version unique** dans `plugin.json` (`.claude/factory-version` n'est plus écrit qu'en mode copie).
- Un plugin ne peut fournir ni règles de permission ni fichier `rules/` : les permissions sont écrites dans le
  `.claude/settings.json` du projet par `install.sh`, et `session-start` injecte `rules/factory.md` en mode plugin.

### Indépendance vis-à-vis de l'emplacement du kit
- Les hooks trouvent le kit à partir de leur propre emplacement (`kit_root`, `kit_path`, `kit_mode`, `kit_version`
  dans `lib.sh`) : même code en mode copie et en mode plugin.
- Agents, commandes, skills et règles désignent le kit par `<kit>`, dont `session-start` annonce le chemin ;
  l'orchestrateur le transmet aux agents (qui ne reçoivent pas le message de début de session).

### Outils
- `tools/install.sh --mode plugin|copy` (défaut : `copy`), `--marketplace <owner/repo>` ; migration copie → plugin.
- `tools/check-references.sh` vérifie aussi le plugin : manifestes, nom cohérent avec la marketplace, version sémantique,
  scripts déclarés dans `hooks.json`.
- `tools/test-hooks.sh copy|plugin` : 127 scénarios en mode copie, 129 en mode plugin ; la CI joue les deux modes et la migration.

## v3.4.1 — Redis validé, retours de la première intégration
Rien d'obligatoire dans un projet existant : mise à jour recommandée avec `tools/install.sh`.
Si le projet utilise `mail` ou `redis` : retirer la valeur par défaut des mots de passe dans `application.yml`
et mettre `password: ""` dans `application-local.yml` (voir les références).

- **`redis` passe en « testée »** (Bibliothèque : `/add-integration redis`, cache de la liste des livres disponibles,
  test réel avec Redis coupé). La référence intègre ce qui a été validé : mot de passe sans valeur par défaut et profil
  `local`, `repositories.enabled: false`, `REJECT_COMMANDS` par `LettuceClientOptionsBuilderCustomizer`, codec JSON
  strict sans nom de classe, une seule clé pour une liste paramétrée, invalidation après commit, lecture à trois issues
  (pas d'écriture quand Redis est injoignable), contrôle des bornes du domaine dans le codec, configurations de test
  séparées, health check et bruit des reconnexions de Lettuce, commandes `redis-cli` utiles.
- **`mail`** : mot de passe sans valeur par défaut (même incohérence avec le socle que `redis`).
- **`/feature`** : nouvel **arrêt après la revue** — le verdict est présenté à l'humain, qui décide avant tout commit.
- **`factory.md`** : les fichiers se lisent avec l'outil Read, jamais avec `cat`/`head`/`Get-Content`
  (moins de demandes d'autorisation, respect direct des règles de permission).
- **`session-start`** annonce les **options effectives** (valeur du projet, sinon celle du profil).
- **Profil `top`** : Docker aussi pour les services sans installation native (Redis sous Windows, Mailpit, MinIO).
- **README** : piège de la commande `bash` dans PowerShell (lance WSL au lieu de Git Bash).
- `tools/test-hooks.sh` : 125 scénarios.

## v3.4.0 — Conventions et intégrations
**À faire dans un projet existant** :
1. Mettre à jour avec `tools/install.sh`, dans une branche dédiée. Le script crée `.claude/stack.json`
   (profil `top`, intégration `postgresql`) et supprime l'ancien skill `spring-boot-conventions`.
   **Relire `stack.json`** : ajouter les intégrations déjà utilisées par le projet, et les options qui s'écartent du profil.
2. Architecture `couche` uniquement : `/update-architecture-test` (couches `Listener` et `Infra` ajoutées).

### Conventions
- Le skill `spring-boot-conventions` est remplacé par le skill **`conventions`** : un **socle** non négociable,
  des **profils** (premier profil : `top`, construit à partir de ce qui a été validé sur Bibliothèque) et des **options**
  (`mapping` : manuel / mapstruct ; `lombok` : interdit / hors-domaine ; `errors` : problem-detail ; `ids` : uuid / sequence).
- Priorités : architecture > socle > options du projet > profil.

### Intégrations
- Nouveau skill **`integrations`** : une référence par technologie, avec un contrat de 12 sections, un statut
  (`testée` / `non testée`) et un `rules.conf`. Premières références : **postgresql** (testée), **redis**, **mail**,
  **stockage-objet**, **rabbitmq**, **kafka** (non testées), plus `_template`.
- **Rôles techniques** : vocabulaire unique (`skills/integrations/roles.conf`) ; chaque architecture déclare où va chaque
  rôle (`roles.conf` + sous-section « Rôles techniques »). Couche : nouvelles couches `Listener` et `Infra` dans `ArchitectureTest`.
- **`.claude/stack.json`** : profil, options, intégrations actives ; modifiable uniquement avec l'accord de l'humain (règle `ask`).
- **Commande `/add-integration <techno>`** : dépendances, configuration par variables d'environnement, Testcontainers,
  santé, déclaration dans `stack.json`.

### Hooks et outils
- `guard-architecture.sh` applique aussi le `rules.conf` de chaque intégration active : une bibliothèque d'intégration
  n'est acceptée que dans les packages de ses rôles ou dans `config`.
- `session-start.sh` annonce la stack : profil, options, intégrations actives avec leur statut et leur résumé.
- `tools/install.sh` conserve `stack.json`, le crée s'il manque, et supprime les fichiers retirés du kit
  (`tools/removed-files.txt`).
- `tools/check-references.sh` vérifie aussi les rôles des architectures, les intégrations, les conventions et le `stack.json`.
- `tools/test-hooks.sh` : 123 scénarios.
- Agents : `architect`, `backend-dev`, `test-writer` et `reviewer` chargent `conventions` et `integrations`.

## v3.3.1 — Retours du niveau 2 MCP (Bibliothèque)
Documentation uniquement : rien à faire dans un projet existant (mise à jour facultative avec `tools/install.sh`).
- `extras/mcp/postgres-readonly-role.sql` : se connecter à la base du projet (pas à `postgres`), **trouver** le propriétaire
  des tables au lieu de le supposer, pièges de pgAdmin (transaction unique, seul le dernier résultat affiché), vérifications.
- `extras/mcp/README.md` : piège des variables d'environnement sous Windows (Windows Terminal, IDE), choix de l'option
  d'approbation d'un serveur, vérification de l'utilisateur réellement connecté.
- `docs/ROADMAP-MCP.md` : leçons du niveau 2, validé sur Bibliothèque (forcer l'appel pour tester le hook, écriture cachée dans une CTE).

## v3.3.0 — Tous les systèmes, et MCP
**À faire dans un projet existant** :
1. Mettre à jour avec le nouveau script, dans une branche dédiée : `bash ../factory-dev/tools/install.sh .`
   (sous Windows, avec le bash de Git for Windows). Il migre `factory.json` : `factoryVersion` retiré, `baseBranch` ajouté
   (`develop` par défaut ; vérifiez que c'est bien votre branche d'intégration).
2. Installer **jq** s'il manque (voir le README) : sans lui, les hooks de protection bloquent désormais par sécurité.
3. Architecture `couche` uniquement : lancer `/update-architecture-test` (nouvelle couche `Mcp` dans `ArchitectureTest`).
4. Si le projet avait des règles MCP dans `.claude/settings.local.json`, les retirer : elles sont maintenant dans `settings.json`.

### Portabilité (Linux, macOS, Windows)
- **Hooks lancés par `bash …`** dans `settings.json` : plus besoin du droit d'exécution (perdu lors d'une copie depuis Windows ou d'un zip).
- **jq vérifié** : un hook de protection sans jq bloque au lieu de tout laisser passer ; `session-start` l'annonce avec
  la commande d'installation pour chaque système.
- **`tools/install.sh`** : installation et mise à jour du kit (refuse un changement d'architecture, conserve `factory.json`,
  signale sans les supprimer les fichiers devenus inutiles, complète `.gitattributes`). Remplace les copies manuelles.
- **CI GitHub Actions** (`.github/workflows/factory-ci.yml`) sur Ubuntu, macOS (bash 3.2) et Windows (Git Bash) :
  fins de ligne, syntaxe, contrat des références, tests des hooks, installation puis mise à jour.
- Commandes Maven formulées de façon neutre (« `./mvnw …` depuis `backend/` ») ; README avec les deux variantes
  (bash et PowerShell) ; règles de portabilité dans `factory.md` et dans le `CLAUDE.md` du kit.

### Version et point de départ
- **La version du kit sort de `factory.json`** (issue #5) : elle est dans `.claude/factory-version`, remplacée à chaque mise à jour.
  `factory.json` ne contient plus que les choix du projet : `architecture` et **`baseBranch`**. `session-start` affiche
  la version et la branche d'intégration, et signale l'ancien champ.
- **`/feature` vérifie le point de départ** avant la spec : aucune modification non commitée, branche courante = `baseBranch`,
  `baseBranch` à jour par rapport au dépôt distant. Sinon elle s'arrête et explique ; elle ne corrige jamais seule.

### MCP
- **`extras/mcp/`** (optionnel) : blocs `.mcp.json` pour GitHub et PostgreSQL (Docker ou pipx), rôle SQL `claude_ro`
  en lecture seule, guide par système. Aucun secret : uniquement des variables d'environnement.
- **Garde-fous dans `settings.json`** : `deny` sur la fusion de PR (outil MCP, `gh pr merge`, `glab mr merge`),
  `ask` sur la création d'issue, de PR, de commentaire et de fichier. `guard-bash` bloque aussi les fusions par le shell.
- **Hook `guard-mcp-sql.sh`** (PreToolUse sur `mcp__postgres__.*`) : une seule instruction de lecture, aucun mot-clé
  d'écriture (y compris dans une CTE, un `SELECT … INTO` ou un `EXPLAIN ANALYZE`), aucun commentaire, aucun `$$`,
  aucune fonction à effet de bord.
- **Nouvelle commande `/add-mcp-server`** : installe l'infrastructure validée sur Bibliothèque (Spring AI, Streamable HTTP,
  profil `mcp-local` limité à 127.0.0.1, filtres Origin et Host, refus de démarrer avec `prod` ou une adresse non locale,
  tests 401/403). Ne crée aucun outil : ils passent par `/feature`.
- **Références** : emplacement des outils MCP (`adapter.in.mcp` en hexagonal, `<feature>/mcp` en couche), exemple de code,
  tests et points de revue. Couche : nouvelle couche `Mcp` dans `ArchitectureTest` et règle `mcp` dans `rules.conf`.
- **`factory.md`** : section « Serveurs MCP » ; règle sur les données de développement (`docs/dev/`, jamais `db/migration/`).

### Tests et documentation
- `tools/test-hooks.sh` : 100 scénarios (SQL, fusions, version, `baseBranch`, absence de jq) ; hooks lancés sans droit d'exécution.
- Nouveaux documents : `docs/ROADMAP-MCP.md`, `docs/ROADMAP-v4.md`.

## v3.2.0 — Mise à jour sûre d'ArchitectureTest
**À faire dans un projet existant** : mettre à jour `.claude/` (README, « Mettre à jour un projet existant »), puis lancer
`/update-architecture-test`. Aucune retouche du `CLAUDE.md` du projet.

- **Nouvelle commande `/update-architecture-test`** : recopie `ArchitectureTest.java` depuis la référence active, remplace
  toutes les occurrences de `__BASE_PACKAGE__`, refuse si le projet a été initialisé avec une autre architecture,
  présente les règles ajoutées ou modifiées, et ne corrige jamais seule une nouvelle violation.
- **`session-start`** : signale un `ArchitectureTest` qui contient encore `__BASE_PACKAGE__` (ses règles passeraient au vert sans rien vérifier).
- **Classes compilées obsolètes** : ArchUnit analyse `target/classes` ; après la suppression ou le renommage d'une classe,
  un `.class` resté dans `target/` fausse le résultat. Désormais :
  - nouveau hook `post-bash-check.sh` (PostToolUse sur Bash/PowerShell) : rappel non bloquant d'utiliser `clean`
    après un `rm`, `mv`, `git rm`, `git mv`, `Remove-Item`… sur un fichier ou dossier Java ;
  - `backend-dev`, `test-writer` et `reviewer` lancent `./mvnw clean test` ; règle ajoutée dans `.claude/rules/factory.md`.
- `tools/test-hooks.sh` : 67 scénarios.

## v3.1.0 — Retours du premier test complet (Bibliothèque)
**À faire dans un projet existant** : mettre à jour `.claude/` (voir README, « Mettre à jour un projet existant »),
puis **retirer du `CLAUDE.md` du projet** les sections désormais fournies par `.claude/rules/factory.md` :
« Architecture backend », « Règles non négociables », « Workflow attendu ».

- **CLAUDE.md découpé** : règles communes dans `.claude/rules/factory.md` (chargé automatiquement, remplacé à chaque mise à jour),
  modèle de projet `CLAUDE.template.md`, et un `CLAUDE.md` propre au dépôt du kit.
- **Communication entre modules** :
  - hexagonal : contrat public `<module>.api` (JDK uniquement), implémenté par `<module>.adapter.in.module`,
    appelé depuis un adapter sortant de l'autre module ; nouvelles règles ArchUnit `modules_talk_only_through_their_api`
    et `module_api_is_self_contained`, règle `api` dans `rules.conf` ;
  - couche : appel du service, des DTO et des exceptions d'une autre feature uniquement ; règle ArchUnit
    `features_talk_only_through_service_and_dto`.
- **Tests** : `test-writer` écrit tous les tests dans `/feature` ; `backend-dev` implémente et compile (fin de la contradiction
  avec la référence, qui le précise désormais).
- **/feature** : attend explicitement la fin de chaque agent (y compris en arrière-plan), enregistre la spec avec les décisions
  et le plan validé dans `docs/specs/` (plus de dossier temporaire), lit `factory.json` avec Read.
- **Hooks** :
  - `guard-bash` : la lecture de `factory.json` n'est plus bloquée (seules les écritures vers ce fichier le sont) ;
    seuls les `.sql` de `db/migration` sont protégés (un `.gitkeep` peut être supprimé) ; `git push … feature/maintenance`
    n'est plus confondu avec `main` ; push `+branche` (forcé) bloqué ; s'applique aussi à l'outil PowerShell ;
  - `post-edit-check` : utilise `mvn` si `mvnw` est absent ; distingue une erreur de compilation (bloquante) d'un Maven
    qui ne démarre pas (avertissement non bloquant, au plus une fois par heure) au lieu de se taire ;
  - `guard-files` : `.env.example` n'est plus bloqué ;
  - fonctions communes dans `lib.sh` ; chemins `C:\…`, `C:/…` et `/c/…` (Git Bash) normalisés partout.
- **Règle de travail** : les fichiers source se créent avec Write/Edit, jamais par le shell (les hooks ne voient que ces outils).
- **Nouveau** : `tools/test-hooks.sh` (61 scénarios).

## v3.0.0 — Architecture au choix
- **Abstraction de l'architecture** : nouveau skill aiguilleur `architecture` et références interchangeables
  dans `.claude/skills/architecture/references/` (`couche`, `hexagonal`, `_template`).
- **Choix en dur** dans `.claude/factory.json`, verrouillé (hooks `guard-files` et `guard-bash`, règle `deny`).
- **Contrat des références** : 9 sections obligatoires dans `REFERENCE.md`, plus `ArchitectureTest.java`,
  `rules.conf` et `scaffold.md` ; vérification par `tools/check-references.sh`.
- **Agents génériques** (`architect`, `backend-dev`, `test-writer`, `reviewer`) : ordre d'implémentation, règles,
  tests, grille de revue et format de réponse lus dans la référence active ; skills préchargés via `skills:`.
- **CLAUDE.md générique** ; nouveau hook `SessionStart` qui injecte le résumé de l'architecture active
  et détecte un `ArchitectureTest` généré pour une autre architecture.
- **Hook `guard-architecture.sh`** : moteur générique qui applique le `rules.conf` de la référence active.
  `post-edit-check.sh` ne fait plus que la compilation et Prettier.
- `/init-hexagonal` remplacé par **`/init-architecture`**.
- `spring-boot-conventions` débarrassé de toute règle propre à une architecture.
- **Correctif Windows** : les hooks normalisent les chemins (`\` → `/`) et ignorent les `\r` de `jq`.
  En v2, le contrôle d'architecture ne se déclenchait pas sous Windows à cause des séparateurs `\`.

## v2.0 — Factory hexagonale
- Architecture hexagonale imposée, roadmap détaillée, CI optionnelle (`extras/ci/`).
