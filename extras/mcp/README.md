# Serveurs MCP optionnels

Comme la CI, les serveurs MCP sont **optionnels** : chaque projet choisit ceux dont il a besoin.
Les garde-fous, eux, sont **déjà actifs** dans le kit (`.claude/settings.json` et le hook `guard-mcp-sql.sh`) :
une règle qui vise un serveur absent du projet est simplement sans effet.

| Fichier | Serveur | Variable d'environnement |
|---|---|---|
| `github.json` | GitHub (issues, PR, lecture du code) | `GITHUB_MCP_TOKEN` |
| `postgres-docker.json` | Postgres MCP Pro, lancé par Docker, mode `restricted` | `FACTORY_DB_RO_URI` |
| `postgres-pipx.json` | Postgres MCP Pro installé avec `pipx install postgres-mcp`, sans Docker | `FACTORY_DB_RO_URI` |
| `postgres-readonly-role.sql` | Rôle PostgreSQL `claude_ro` en lecture seule | — |

## 1. Composer le `.mcp.json` du projet
Le fichier `.mcp.json`, à la racine du projet, est **versionné et partagé** par l'équipe (portée *project*).
Fusionnez dans un seul objet `mcpServers` les blocs des serveurs choisis, par exemple GitHub et PostgreSQL :

```json
{
  "mcpServers": {
    "github":   { "...": "contenu de github.json" },
    "postgres": { "...": "contenu de postgres-docker.json ou postgres-pipx.json" }
  }
}
```

**Aucun secret dans ce fichier** : seulement des références `${VARIABLE}`, que Claude Code remplace au démarrage.
Au premier lancement, Claude Code demande à chaque développeur d'**approuver** les serveurs du `.mcp.json` :
une modification du dépôt ne peut pas brancher un serveur à son insu.

## 2. Définir les variables d'environnement (sur chaque poste)
**macOS / Linux** (`~/.zshrc` ou `~/.bashrc`) :
```bash
export GITHUB_MCP_TOKEN="github_pat_…"
export FACTORY_DB_RO_URI="postgresql://claude_ro:<mot_de_passe>@localhost:5432/<base>"
```
**Windows** (PowerShell, variable utilisateur permanente, puis rouvrir le terminal) :
```powershell
[Environment]::SetEnvironmentVariable("GITHUB_MCP_TOKEN", "github_pat_…", "User")
[Environment]::SetEnvironmentVariable("FACTORY_DB_RO_URI", "postgresql://claude_ro:<mot_de_passe>@localhost:5432/<base>", "User")
```

## 3. GitHub : moindre privilège
- Préférez un jeton **fine-grained**, limité aux dépôts du projet, avec les seuls droits nécessaires
  (lecture du contenu ; issues et pull requests en écriture si vous voulez que Claude en crée).
- La fusion reste interdite à Claude par trois chemins : la règle `deny` sur `mcp__github__merge_pull_request`,
  la règle `deny` sur `gh pr merge`, et le hook `guard-bash.sh`.
- Créer une issue, une PR, un commentaire ou un fichier demande votre accord (règles `ask`).

## 4. PostgreSQL : trois lignes de défense
1. **Le rôle `claude_ro`** (`postgres-readonly-role.sql`) : droit `SELECT` uniquement, transactions en lecture seule,
   requêtes coupées après 15 s.
2. **Le mode `restricted`** du serveur Postgres MCP Pro : lecture seule et limites de ressources.
3. **Le hook `guard-mcp-sql.sh`** : une seule instruction, commençant par `SELECT`, `WITH`, `EXPLAIN`, `SHOW`,
   `VALUES` ou `TABLE` ; aucun mot-clé d'écriture, aucun commentaire, aucun `$$`.

Notes par système pour la variante Docker :
- **Windows et macOS (Docker Desktop)** : l'image remplace `localhost` par l'adresse de la machine hôte.
  Si PostgreSQL refuse la connexion, autorisez le réseau de Docker dans `pg_hba.conf`.
- **Linux** : ajoutez `"--network=host"` juste après `"--rm"` dans `args`, ou utilisez la variante `pipx`.

## 5. Vérifier
Relancez Claude Code à la racine du projet, puis `/mcp` : chaque serveur doit être **connected**.
Exercices guidés : `docs/ROADMAP-MCP.md` du kit.
