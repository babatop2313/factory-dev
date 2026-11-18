# Règles de la Top Factory (communes à tous les projets)

> Fichier fourni par le kit `top-factory`, chargé à chaque session : copié dans `.claude/rules/` (mode copie) ou injecté
> par le hook `session-start` (mode plugin). **Ne pas modifier dans un projet** : il est remplacé à chaque mise à jour du kit.
> Ce qui est propre au projet va dans le `CLAUDE.md` à la racine.

## Où est le kit
- **`<kit>`** désigne le dossier du kit, annoncé au début de chaque session : `.claude` en mode copie, le dossier du
  plugin en mode plugin. Les fichiers du **projet** (`.claude/factory.json`, `.claude/stack.json`, `CLAUDE.md`) restent
  toujours dans le projet.
- **`<backend>`** et **`<frontend>`** désignent les dossiers du backend (Spring Boot) et du frontend (Angular), relatifs
  à la racine du projet et annoncés au début de chaque session. Ils viennent de `.claude/factory.json` (champs `backend`
  et `frontend`, par défaut `backend` et `frontend` ; `.` = racine du dépôt). Ne suppose jamais que le backend s'appelle `backend`.
- Quand tu délègues à un agent, transmets-lui le chemin de `<kit>`, les valeurs de `<backend>` et `<frontend>`, et le
  chemin de la référence d'architecture active : un agent ne reçoit pas le message de début de session.

## Architecture backend
- **L'architecture est choisie une seule fois, au démarrage du projet, dans `.claude/factory.json`** (champ `architecture`).
  Elle ne change jamais en cours de développement.
- Les règles complètes sont dans `<kit>/skills/architecture/references/<architecture>/REFERENCE.md`.
  Leur résumé est injecté au début de chaque session par le hook `session-start.sh`.
- Avant **toute** tâche backend (conception, code, tests, revue, bug) : charger le skill `architecture`
  et lire la référence active. N'utiliser aucune autre référence.
- Ne jamais modifier `.claude/factory.json` (verrouillé par un hook et une règle de permission).
  Le **lire** est autorisé, de préférence avec l'outil Read. Il contient aussi `baseBranch`, la branche d'intégration
  d'où partent les branches `feature/*`. La version du kit est dans `.claude/factory-version`.

## Conventions et intégrations
- **`.claude/stack.json`** décrit la stack du projet : profil de conventions, options (mapping, Lombok, erreurs, ids)
  et **intégrations actives** (postgresql, redis, kafka…). Contrairement à `factory.json`, il évolue au fil du projet,
  mais **toujours avec l'accord de l'humain** (règle de permission `ask`), de préférence par `/add-integration`.
- Avant toute tâche backend : skill `conventions` (socle, profil, options). Priorités : architecture > socle > options > profil.
- Dès qu'une tâche touche une technologie : skill `integrations`, en ne lisant **que** la référence de cette technologie.
  Son code va dans le package de son rôle (`roles.conf` de l'architecture) ou dans `config` ; jamais dans le domaine.
  Le hook `guard-architecture.sh` le vérifie pour chaque intégration active.
- Une technologie absente de `stack.json` ne s'ajoute pas « en passant » : `/add-integration <techno>` d'abord.
- Une référence « non testée » s'applique avec prudence : vérifier artefacts et propriétés dans la documentation officielle.

## Façon de travailler
- **Les fichiers source se créent et se modifient avec les outils Write et Edit, jamais par le shell**
  (`echo >`, `cat <<EOF`, `sed -i`, boucle `mkdir` + écriture…). Les hooks de vérification (architecture, compilation,
  fichiers protégés) ne surveillent que Write et Edit : un fichier écrit par le shell leur échappe.
- **Les fichiers se lisent avec l'outil Read** (et se cherchent avec Glob et Grep), jamais avec `cat`, `head`, `tail`,
  `type` ou `Get-Content` : Read respecte directement les règles de permission (secrets, `.env`) et évite des demandes
  d'autorisation inutiles à l'humain.
- Le shell sert à compiler, tester, lire l'historique Git et créer des branches ou des commits.
- Si un hook bloque une action, ne pas chercher à le contourner : corriger, ou signaler le blocage à l'humain.
- **Commandes portables** (le kit tourne sous Windows, macOS et Linux) : lancer Maven depuis `<backend>` avec `./mvnw` ;
  ne pas supposer un shell précis (pas de `&&` dans PowerShell 5, pas de syntaxe propre à bash 4 dans les scripts).
- **Données de développement** (jeu d'essai pour la base locale) : dans `docs/dev/`, **jamais dans `db/migration/`**,
  sinon Flyway les appliquerait en production. C'est l'humain qui exécute ces scripts.
- **Après la suppression, le déplacement ou le renommage d'un fichier Java**, compiler et tester avec `./mvnw clean test`
  (ou `clean compile`) : sinon les `.class` obsolètes de `target/` faussent `ArchitectureTest`, qui analyse les classes compilées.

## Règles non négociables
- Respecter la règle de dépendance de la référence d'architecture active. Une violation est toujours bloquante.
- Jamais d'entité JPA exposée par un contrôleur : toujours des DTO.
- Toute modification de schéma passe par une nouvelle migration Flyway ; ne jamais modifier une migration existante.
- Pas de secret dans le code ni dans `application.yml` : variables d'environnement. Jamais de token ni de donnée personnelle dans les logs.
- Toute règle métier est testée, dans la couche où la référence place la logique métier.
- `ArchitectureTest` doit toujours passer ; on corrige le code, jamais les règles.
- Ne jamais pousser sur `main`/`develop` ni merger : on produit une branche et une Pull Request / Merge Request.

## Serveurs MCP
- **Côté Claude Code** : serveurs optionnels décrits dans `extras/mcp/` du kit. Secrets uniquement dans des variables
  d'environnement (`${VAR}` dans `.mcp.json`), jamais en clair. La fusion de PR/MR reste interdite, par tous les chemins.
- **Base de données** : lecture seule. Le hook `guard-mcp-sql.sh` bloque toute requête qui n'est pas une lecture simple ;
  ne pas chercher à le contourner.
- **Côté application** (`/add-mcp-server`) : un outil MCP est un **adapter entrant**, placé là où la référence d'architecture
  l'indique. Il n'appelle que ce qu'un contrôleur a le droit d'appeler, renvoie des DTO sans id technique, est en
  **lecture seule par défaut** (une écriture exige un JWT et `@PreAuthorize`), et sa description est précise :
  c'est ce que lit le modèle pour choisir l'outil.
- Distinguer ce que renvoie un outil de ce qu'on en déduit : ne jamais présenter une déduction comme une donnée de l'outil.

## Workflow attendu
1. Spec dans `docs/specs/<feature>.md` (agent `spec-writer`), validée par l'humain.
2. Plan technique (agent `architect`) validé par l'humain, enregistré dans `docs/specs/<feature>-plan.md`.
3. Implémentation (agent `backend-dev`) dans l'ordre d'implémentation de la référence d'architecture.
4. Tests (agent `test-writer`) selon la section « Tests par couche » de la référence.
5. Revue (agent `reviewer`) → corrections.
6. Verdict présenté à l'humain, qui décide (corrections ou validation) **avant tout commit**.
7. Commit au format Conventional Commits : `feat(<module>): <description>`.

## Commandes de la factory
| Commande | Rôle |
|---|---|
| `/init-architecture <module>` | Une fois au démarrage : ArchUnit, squelette du premier module |
| `/update-architecture-test` | Après une mise à jour du kit : recopie `ArchitectureTest` depuis la référence active |
| `/feature <besoin>` | Point de départ vérifié → spec → plan → code → tests → revue |
| `/add-integration <techno>` | Brancher une technologie (dépendances, configuration, Testcontainers) et la déclarer dans `stack.json` |
| `/add-mcp-server` | Une fois, si besoin : infrastructure MCP du backend (Spring AI, profil `mcp-local` sécurisé) |
| `/fix-bug <bug>` | Test qui reproduit → correction → revue |
| `/review-mr [branche cible]` | Revue des changements de la branche courante |
