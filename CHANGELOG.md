# Changelog

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
