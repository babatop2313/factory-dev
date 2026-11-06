# CLAUDE.md — dépôt du kit Claude Factory

> Ce dépôt **est le kit lui-même**, pas une application. Il ne contient pas de code Spring Boot.
> Les agents, commandes, hooks et références qu'il contient sont destinés à être **copiés dans des projets**.
> Le fichier `.claude/rules/factory.md` est chargé ici aussi, mais ses règles « backend » concernent les projets,
> pas ce dépôt. De même, le hook `session-start.sh` annonce l'architecture de `factory.json` : c'est la valeur
> par défaut livrée aux projets.

## Ce que contient le dépôt
| Élément | Rôle |
|---|---|
| `.claude/` | Le kit à copier dans chaque projet (agents, commandes, hooks, skills, rules, settings, factory.json) |
| `.claude/skills/architecture/references/` | Une référence par architecture (`couche`, `hexagonal`) + `_template` |
| `CLAUDE.template.md` | Modèle du `CLAUDE.md` d'un projet (à copier sous le nom `CLAUDE.md`) |
| `tools/check-references.sh` | Vérifie que chaque référence respecte le contrat |
| `tools/test-hooks.sh` | Tests automatiques des hooks (les deux architectures, chemins Windows, verrou) |
| `docs/ROADMAP.md` | Parcours de montée en compétences |
| `extras/ci/` | Exemples CI optionnels (GitLab, Jenkins) |

## Travailler sur le kit
- **Avant tout commit** : `bash tools/check-references.sh` puis `bash tools/test-hooks.sh`. Les deux doivent être verts.
- Modifier une référence : respecter les 9 sections de `REFERENCE.md` (titres exacts) et garder
  la première ligne `// architecture: <nom>` de `ArchitectureTest.java`.
- Ajouter une architecture : copier `references/_template/`, voir le README.
- Les agents restent **génériques** : aucune règle propre à une architecture dans `.claude/agents/`,
  tout passe par la référence active.
- Les scripts de `.claude/hooks/` doivent fonctionner sous Linux, macOS et Windows (Git Bash) :
  normaliser les chemins (`\` → `/`), retirer les `\r`, ne dépendre que de `bash`, `jq`, `grep`, `sed`, `awk`.
- Noter chaque changement dans `CHANGELOG.md` et monter `factoryVersion` dans `.claude/factory.json`.
- Workflow Git : branche `feature/…` depuis `main`, Pull Request, tag de version après fusion (`v3.1`, …).
