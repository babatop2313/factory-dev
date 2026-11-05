# Changelog

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
