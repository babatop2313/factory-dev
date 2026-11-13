# Changelog

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
- **Nouveau** : `tools/test-hooks.sh` (67 scénarios).

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
