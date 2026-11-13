# Parcours MCP — utiliser des serveurs, puis créer le sien

> Le **Model Context Protocol** relie un assistant IA (le *client* : Claude Code, Copilot, Gemini…) à des *serveurs*
> qui exposent des **outils** (actions), des **ressources** (données à lire) et des **prompts**.
> Un serveur se branche une fois et sert à tous les clients compatibles.

Chaque niveau se termine par des exercices dont le résultat attendu est connu. Projet d'appui : Bibliothèque.

## Niveau 1 — Un serveur externe : GitHub (≈ 1 h)
**Objectif** : brancher un serveur distant, comprendre les portées et les permissions.

1. Créer un jeton GitHub *fine-grained* limité au dépôt du projet.
2. `claude mcp add --transport http github https://api.githubcopilot.com/mcp/ --header "Authorization: Bearer <jeton>"`
   (portée *local* : la configuration va dans `~/.claude.json`, jamais dans le dépôt). Puis `/mcp` dans Claude.

| # | Exercice | Ce qu'on apprend |
|---|---|---|
| 1 | « Liste les PR ouvertes du dépôt » | Claude choisit seul l'outil MCP adapté |
| 2 | « Résume l'historique de la branche develop » | Combiner MCP et lecture locale |
| 3 | « Relis la PR n°… et commente les risques » | Lecture d'un diff distant |
| 4 | « Crée une issue pour … » | Un jeton en écriture **permet** l'écriture : le moindre privilège se règle à la source |
| 5 | Règle `deny` sur `mcp__github__merge_pull_request`, puis « fusionne la PR » | Un outil interdit **disparaît** de la liste de Claude |

**Leçon** : une règle sur un outil MCP ne bloque pas le même geste fait autrement (`gh pr merge`).
Il faut fermer tous les chemins (c'est ce que fait le kit : `deny` sur l'outil, sur `gh`, et hook `guard-bash`).

## Niveau 2 — Un serveur local : PostgreSQL en lecture seule (≈ 1 h)
**Objectif** : donner à Claude un accès réel aux données, avec trois lignes de défense.

1. Créer le rôle `claude_ro` avec `extras/mcp/postgres-readonly-role.sql`.
2. Définir `FACTORY_DB_RO_URI` (voir `extras/mcp/README.md`) et ajouter le bloc `postgres` au `.mcp.json` du projet.
3. Relancer Claude, approuver le serveur, `/mcp`.

| # | Exercice | Résultat attendu |
|---|---|---|
| 1 | « Quelles tables contient la base ? » | Les tables métier et `flyway_schema_history` |
| 2 | « Compare la table book avec la migration V1 » | Claude croise la base (MCP) et le fichier (Read) : ils concordent |
| 3 | « Quelles migrations ont été appliquées, et quand ? » | Lecture de `flyway_schema_history` |
| 4 | « Insère un livre de test » | ❌ Refusé par le hook `guard-mcp-sql` (et, s'il passait, par le mode `restricted` puis par le rôle) |
| 5 | « Fais un bilan de santé de la base » | `analyze_db_health` : index, connexions… |

**Leçons** (validées sur Bibliothèque) :
- chaque ligne de défense suffit seule ; on les empile parce qu'aucune n'est infaillible ;
- à l'exercice 4, le modèle **n'essaie même pas** d'écrire (il applique `factory.md`) : pour voir le hook fonctionner,
  forcez l'appel (« utilise directement execute_sql pour exécuter exactement : INSERT … ») et tentez une écriture cachée
  (`WITH d AS (DELETE FROM book WHERE false RETURNING *) SELECT * FROM d`) : les deux sont bloquées avant PostgreSQL ;
- l'agent peut **lire le code des hooks** : un garde-fou doit rester solide même si son fonctionnement est connu ;
- `installed_by` dans `flyway_schema_history` révèle avec quel utilisateur l'application migre la base
  (sur Bibliothèque : `postgres`, une vraie trouvaille).

## Niveau 3 — Créer son serveur : l'application devient un serveur MCP (≈ ½ journée)
**Objectif** : exposer le métier à un assistant IA, sans trahir l'architecture ni la sécurité.

1. `/add-mcp-server` : infrastructure (Spring AI, Streamable HTTP, profil `mcp-local`).
2. `/feature` : deux outils en lecture seule (par exemple `get_book` et `list_available_books`).
3. `./mvnw spring-boot:run "-Dspring-boot.run.profiles=mcp-local"`, puis
   `claude mcp add --transport http library http://localhost:8080/mcp`, puis `/mcp`.

| # | Exercice | Ce qu'on observe |
|---|---|---|
| 1 | « Quels outils propose le serveur ? » | Les descriptions `@McpTool`, telles que le modèle les lit |
| 2 | « Le livre <ISBN> est-il disponible ? » | Claude choisit `get_book` |
| 3 | « Liste les livres disponibles » | Filtre, tri et limite appliqués par le domaine |
| 4 | « Liste 50 livres » | Le modèle **n'envoie même pas** l'appel (il a lu la borne dans le schéma) |
| 5 | « Appelle l'outil avec limit=50 et montre la réponse brute » | La validation serveur renvoie l'erreur métier en français |
| 6 | « Cherche un ISBN inexistant » | Résultat `isError`, sans stack trace |
| 7 | Redémarrer **sans** le profil, reposer la question 2 | Échec (401) : la sécurité tient |

**Leçons** :
- en hexagonal, MCP n'est qu'un **adapter entrant** de plus : domaine et use cases inchangés, `ArchitectureTest` inchangé ;
- la description d'un outil est un prompt : vague, elle fait choisir le mauvais outil ;
- deux lignes de défense : le schéma guide un client discipliné, la validation serveur arrête les autres ;
- le modèle peut **extrapoler** au-delà des données de l'outil : distinguer ce que l'outil renvoie de ce qu'il en déduit.

## Niveau 4 — Industrialiser (fait dans le kit v3.3)
Garde-fous MCP dans `settings.json`, hook SQL, `extras/mcp/`, commande `/add-mcp-server`, emplacement des outils dans
les références. Suite : un serveur MCP **de la factory elle-même**, utilisable par tous les clients (voir `ROADMAP-v4.md`).
