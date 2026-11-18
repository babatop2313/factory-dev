# CLAUDE.md — dépôt du kit Top Factory

> Ce dépôt **est le kit lui-même**, pas une application. Il ne contient pas de code Spring Boot.
> Depuis la v4, c'est un **plugin Claude Code** (`top-factory`) et sa **marketplace** (`top`).
> Les agents, commandes, skills, hooks et règles sont destinés aux **projets** : ils ne s'appliquent pas à ce dépôt.
> Pour les essayer, ouvrir un projet de test avec `claude --plugin-dir <chemin de ce dépôt>`.

## Ce que contient le dépôt
| Élément | Rôle |
|---|---|
| `.claude-plugin/plugin.json` | Manifeste du plugin : nom `top-factory`, **version du kit** (source unique) |
| `.claude-plugin/marketplace.json` | Marketplace `top` (`source: "./"`) |
| `agents/`, `commands/` | Sous-agents et commandes du kit (`commands/init.md` : mode plugin seulement, non copiée en mode copie) |
| `skills/architecture/references/` | Une référence par architecture (`couche`, `hexagonal`) + `_template` |
| `skills/conventions/` | Socle, profils (`top`), options (mapping, lombok, errors, ids) |
| `skills/integrations/` | Vocabulaire des rôles (`roles.conf`) et une référence par technologie + `_template` |
| `hooks/hooks.json`, `hooks/scripts/` | Hooks du plugin (`${CLAUDE_PLUGIN_ROOT}`) ; `install.sh` les adapte au mode copie |
| `rules/factory.md` | Règles communes (copiées dans `.claude/rules/` ou injectées par `session-start`) |
| `templates/` | Fichiers créés dans les projets : `factory.json`, `stack.json`, `settings.json` (permissions seulement) |
| `CLAUDE.template.md` | Modèle du `CLAUDE.md` d'un projet |
| `tools/install.sh` | Prépare ou met à jour un projet (`--mode plugin` ou `copy`, `--detect`, `--backend`, `--frontend`, `--integrations`) ; appelé par `/top-factory:init` |
| `tools/removed-files.txt` | Fichiers retirés du kit, supprimés des projets en mode copie |
| `tools/check-references.sh` | Contrats des références et cohérence du plugin |
| `tools/test-hooks.sh` | Tests des hooks : `copy` puis `plugin` |
| `docs/`, `extras/` | Roadmaps ; CI et serveurs MCP optionnels |
| `.github/workflows/factory-ci.yml` | CI : Ubuntu, macOS (bash 3.2) et Windows (Git Bash), deux modes |

## Travailler sur le kit
- **Avant tout commit** : `bash tools/check-references.sh`, `bash tools/test-hooks.sh copy` et `bash tools/test-hooks.sh plugin`.
- **Chemins** : dans les agents, commandes, skills et règles, le dossier du kit s'écrit `<kit>` (jamais `.claude/skills/…`) ;
  les fichiers du projet restent `.claude/factory.json`, `.claude/stack.json`, `CLAUDE.md`. Les dossiers du projet
  s'écrivent `<backend>` et `<frontend>` (jamais `backend/` en dur : `check-references.sh` le refuse) ; dans les
  scripts, `backend_rel`, `backend_dir`, `frontend_rel`, `frontend_dir` de `lib.sh`. Dans les scripts, utiliser
  `kit_root`, `kit_path`, `kit_mode` et `kit_version` de `hooks/scripts/lib.sh`, qui fonctionnent dans les deux modes.
- **Hooks** : déclarés dans `hooks/hooks.json` avec `${CLAUDE_PLUGIN_ROOT}/hooks/scripts/…` ; ne jamais en mettre dans
  `templates/settings.json` (ils seraient en double en mode plugin).
- Modifier une référence d'architecture : respecter les 9 sections de `REFERENCE.md` (titres exacts), garder la première
  ligne `// architecture: <nom>` de `ArchitectureTest.java`, et un `roles.conf` qui couvre tout le vocabulaire.
- Ajouter une intégration : copier `skills/integrations/references/_template/`, statut « non testée » ; la passer à
  « testée » seulement après validation sur un projet réel. Ajouter un rôle : `skills/integrations/roles.conf`, puis dans
  le `roles.conf` et la sous-section « Rôles techniques » de **chaque** architecture.
- Retirer un fichier du kit : l'ajouter à `tools/removed-files.txt` (avec son chemin dans un projet en mode copie).
- Les agents restent **génériques** : aucune règle propre à une architecture dans `agents/`.
- Scripts portables (Linux, macOS, Windows Git Bash) : chemins normalisés, `\r` retirés, seulement `bash`, `jq`, `grep`,
  `sed`, `awk` ; **compatibles bash 3.2** (ni `declare -A`, ni `${x,,}`, ni `mapfile`) ; `sed -E`, jamais `grep -P`.
- Un hook de **protection** sans jq bloque (`need_jq block`) ; un hook de **confort** ne fait rien (`need_jq skip`).
- **Version** : uniquement dans `.claude-plugin/plugin.json` (`install.sh` écrit `factory-version` en mode copie).
  Noter chaque changement dans `CHANGELOG.md`.
- Workflow Git : branche depuis `main`, Pull Request, tag de version après fusion (`v4.0`, …).
