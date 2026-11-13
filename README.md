# Claude Factory — kit de software factory réutilisable

Une « usine logicielle » pilotée par Claude Code pour un stack **Java/Spring Boot + Angular + PostgreSQL**,
avec une **architecture backend au choix**, fixée une fois pour toutes au démarrage de chaque projet.

```
 .claude/factory.json  { "architecture": "couche" | "hexagonal" | …, "baseBranch": "develop" }  ← choisi par l'humain, verrouillé
          │
          ▼
 skill « architecture » → references/<architecture>/REFERENCE.md           ← la seule référence appliquée
          │
          ▼
 /feature "description"
   ├─► étape 0      → point de départ vérifié (aucune modification en cours, baseBranch à jour)
   ├─► spec-writer   → docs/specs/<feature>.md (règles RM-xx)
   ├─► architect     → plan découpé selon les couches de la référence
   ├─► backend-dev   → code, dans l'ordre d'implémentation de la référence
   ├─► frontend-dev  → Angular
   ├─► test-writer   → tests par couche, selon la référence + ArchUnit
   └─► reviewer      → revue : grille de la référence, puis sécurité, perf, tests (lecture seule)
          │
          ▼
 Garde-fous
   ├─ session-start.sh      : injecte le résumé de l'architecture active à chaque session
   ├─ guard-architecture.sh : vérifie les imports à chaque écriture, selon rules.conf de la référence
   ├─ guard-files / guard-bash : verrou de factory.json, secrets, migrations, git (push, fusion)
   ├─ guard-mcp-sql.sh      : lecture seule pour le serveur MCP PostgreSQL
   └─ ArchitectureTest      : règles ArchUnit de l'architecture, sur tout le code
```

## Architectures disponibles

| Valeur dans `factory.json` | Architecture | Règle de dépendance |
|---|---|---|
| `couche` | En couches, découpée par fonctionnalité | `controller → service → repository → entity` |
| `hexagonal` | Hexagonale (ports & adapters) + clean architecture | `adapter → application → domain` |

Pour en ajouter une (clean, monolithe modulaire…) : voir « Ajouter une architecture » plus bas.

## Comment l'abstraction fonctionne
- **Un seul endroit de configuration** : `.claude/factory.json`. Rien d'autre ne contient le nom de l'architecture.
- **Des références au format imposé** : chaque `references/<nom>/REFERENCE.md` a les mêmes 9 sections
  (Résumé, Structure des packages, Règle de dépendance, Ordre d'implémentation, Règles du développeur,
  Exemples de code, Tests par couche, Grille de revue, Format de réponse finale).
- **Des agents génériques** : ils lisent `factory.json`, puis la section de la référence qui les concerne
  (le `backend-dev` lit « Ordre d'implémentation », « Règles du développeur », « Format de réponse finale »…).
- **Des règles communes chargées automatiquement** : `.claude/rules/factory.md` (fourni par le kit, remplacé à chaque mise à jour) ;
  le `CLAUDE.md` du projet ne contient que ce qui lui est propre. Le hook `SessionStart` injecte le résumé de la référence.

## Contenu

| Élément | Rôle |
|---|---|
| `CLAUDE.template.md` | Modèle du `CLAUDE.md` d'un projet : **à copier sous le nom `CLAUDE.md`** et à compléter (contexte, règles métier, commandes) |
| `.claude/rules/factory.md` | Règles communes de la factory, chargées automatiquement dans chaque session |
| `CLAUDE.md` (racine du kit) | Instructions pour travailler **sur le kit lui-même** (pas à copier) |
| `.claude/factory.json` | **Les choix du projet** (architecture, branche d'intégration), verrouillés |
| `.claude/factory-version` | Version du kit installée (remplacée à chaque mise à jour) |
| `.claude/stack.json` | **La stack du projet** : profil et options de conventions, intégrations actives (modifiable avec accord) |
| `.claude/skills/architecture/` | Aiguilleur (`SKILL.md`) + `references/couche`, `references/hexagonal`, `references/_template` |
| `.claude/skills/conventions/` | Socle non négociable, profil `top`, options (mapping, lombok, errors, ids) |
| `.claude/skills/integrations/` | Une référence par technologie (postgresql, redis, mail, stockage-objet, rabbitmq, kafka) + vocabulaire des rôles |
| `.claude/skills/` (autres) | `rest-api-design`, `angular-conventions` |
| `.claude/agents/` | 6 sous-agents génériques |
| `.claude/commands/` | `/init-architecture`, `/update-architecture-test`, `/feature`, `/add-integration`, `/add-mcp-server`, `/fix-bug`, `/review-mr` |
| `.claude/hooks/` | `session-start`, `guard-architecture`, `guard-files`, `guard-bash`, `guard-mcp-sql`, `post-edit-check`, `post-bash-check` (+ `lib.sh`) |
| `tools/install.sh` | **Installe ou met à jour** le kit dans un projet (Linux, macOS, Windows avec Git Bash) |
| `tools/check-references.sh` | Vérifie le contrat des architectures, intégrations, conventions et du `stack.json` |
| `tools/test-hooks.sh` | Tests automatiques des hooks (123 scénarios : architectures, intégrations, chemins Windows, verrou, Maven, SQL, absence de jq) |
| `.github/workflows/factory-ci.yml` | CI du kit sur **Ubuntu, macOS et Windows** à chaque PR |
| `docs/ROADMAP.md` | Parcours de montée en compétences |
| `docs/ROADMAP-MCP.md` | Parcours MCP : utiliser des serveurs, puis créer le sien |
| `docs/ROADMAP-v4.md` | Cap suivant : conventions et intégrations (v3.4), multi-IA et plugin (v4) |
| `extras/ci/` | **Optionnel, pour plus tard** : exemples GitLab CI et Jenkins |
| `extras/mcp/` | **Optionnel** : serveurs MCP (GitHub, PostgreSQL en lecture seule) et rôle SQL `claude_ro` |

## Prérequis (tous systèmes)
| | macOS | Linux | Windows |
|---|---|---|---|
| Claude Code | ✔ | ✔ | ✔ |
| bash | fourni (3.2 suffit) | fourni | **Git for Windows** (fournit Git Bash) |
| jq | `brew install jq` (déjà présent depuis macOS 15) | `sudo apt install jq` / `sudo dnf install jq` | `winget install jqlang.jq` |
| git | ✔ | ✔ | ✔ |

Les hooks sont des scripts bash lancés par `bash …` : ils n'ont pas besoin du droit d'exécution, et fonctionnent
même après une copie depuis Windows. Sans jq, les hooks de protection **bloquent** par sécurité et `session-start`
l'annonce dès l'ouverture de la session.

## Démarrer un projet
Le kit est cloné à côté du projet (`factory-dev/` et `mon-projet/` dans le même dossier).

**macOS / Linux / Git Bash :**
```bash
bash factory-dev/tools/install.sh mon-projet --architecture hexagonal   # ou couche ; --base-branch main si besoin
cd mon-projet && claude
```
**Windows (PowerShell)** — le script s'exécute avec le bash de Git for Windows :
```powershell
& "C:\Program Files\Git\bin\bash.exe" factory-dev/tools/install.sh mon-projet --architecture hexagonal
cd mon-projet; claude
```
Puis, dans Claude :
```
> /init-architecture catalog
> /feature Enregistrer un livre (ISBN unique, titre, auteur, nombre d'exemplaires)
```
Le script crée `.claude/factory.json` (architecture et branche d'intégration, **verrouillés**), copie `CLAUDE.template.md`
en `CLAUDE.md` (à compléter : contexte, règles métier, commandes) et complète `.gitattributes`.

## Mettre à jour un projet existant avec une nouvelle version du kit
Même commande, **sans** `--architecture` (le script refuse tout changement d'architecture) :
```bash
cd factory-dev && git pull && cd ..
bash factory-dev/tools/install.sh mon-projet
```
Le script remplace les fichiers du kit, **conserve `factory.json`** (en le migrant si besoin vers le format actuel),
ne touche ni à `settings.local.json` ni au `CLAUDE.md` du projet, et **signale sans les supprimer** les fichiers
qui n'existent plus dans le kit. Faites-le dans une branche dédiée (`chore/factory-vX.Y.Z`).

Puis, dans Claude : **`/update-architecture-test`**. Il recopie `ArchitectureTest.java` depuis la référence active,
avec le bon package (ne jamais le copier à la main : le marqueur `__BASE_PACKAGE__` doit être remplacé partout),
et lance `./mvnw clean test -Dtest=ArchitectureTest`.

Enfin, relire le `CHANGELOG.md` : il indique si le `CLAUDE.md` du projet doit être retouché.

## Conventions et intégrations
L'architecture ne change jamais ; la stack, elle, évolue. Elle est décrite dans **`.claude/stack.json`** :
```json
{ "profile": "top", "integrations": ["postgresql", "redis"], "conventions": { "mapping": "mapstruct" } }
```
- **Conventions** (skill `conventions`) : un **socle** non négociable, un **profil** (`top`) qui donne les valeurs par défaut,
  et des **options** que le projet peut surcharger (`mapping`, `lombok`, `errors`, `ids`).
  Priorités : architecture > socle > options du projet > profil.
- **Intégrations** (skill `integrations`) : une référence par technologie, avec un contrat vérifié et un statut
  (`testée` / `non testée`). Chaque intégration joue des **rôles** (`sortant-cache`, `entrant-messagerie`…) ; chaque
  architecture dit où va chaque rôle (`roles.conf`). Une nouvelle technologie = une seule référence, valable pour
  toutes les architectures.
- **Garde-fous** : le hook d'architecture refuse une bibliothèque d'intégration hors de ses rôles (ou de `config`) ;
  `session-start` annonce la stack ; modifier `stack.json` demande votre accord.
- **Ajouter une technologie** : `/add-integration redis` (dépendances, configuration, Testcontainers, santé, déclaration) ;
  le code qui l'utilise passe ensuite par `/feature`.

| Intégration | Rôles | Statut |
|---|---|---|
| postgresql | `sortant-persistance` | testée |
| redis | `sortant-cache` | non testée |
| mail | `sortant-notification` | non testée |
| stockage-objet (S3 / MinIO) | `sortant-fichiers` | non testée |
| rabbitmq | `entrant-messagerie`, `sortant-messagerie` | non testée |
| kafka | `entrant-messagerie`, `sortant-messagerie` | non testée |

## Serveurs MCP (optionnel)
- **Utiliser des serveurs** (GitHub, PostgreSQL en lecture seule) : `extras/mcp/README.md`. Les garde-fous sont déjà
  dans le kit : fusion de PR interdite par tous les chemins, création d'issue ou de PR soumise à accord, hook SQL en lecture seule.
- **Exposer son application comme serveur MCP** : `/add-mcp-server` installe l'infrastructure (Spring AI, profil
  `mcp-local` sécurisé) ; les outils se créent ensuite avec `/feature`. Un outil MCP est un adapter entrant :
  la référence d'architecture dit où il va, et ArchUnit le vérifie comme un contrôleur.

## Le verrou d'architecture
| Protection | Effet |
|---|---|
| Hook `guard-files.sh` | Claude ne peut pas modifier `factory.json` avec les outils d'édition |
| Hook `guard-bash.sh` | ni par une commande shell (`>`, `sed -i`, `mv`, `rm`…) |
| Règle `deny` dans `settings.json` | double protection sur l'édition |
| Marqueur `// architecture: <nom>` en tête d'`ArchitectureTest.java` | `session-start.sh` signale toute incohérence avec `factory.json` |
| `/init-architecture` | refuse d'initialiser un projet déjà initialisé avec une autre architecture |

Ces protections empêchent Claude et les erreurs de manipulation de changer l'architecture.
Un humain peut toujours éditer les fichiers à la main : changer d'architecture reste une décision humaine et consciente.

## Ajouter une architecture
1. Copier `.claude/skills/architecture/references/_template/` vers `references/<nom>/`.
2. Remplir les 4 fichiers : `REFERENCE.md` (9 sections, titres exacts), `ArchitectureTest.java`
   (première ligne `// architecture: <nom>`), `rules.conf`, `scaffold.md`.
3. Vérifier : `bash tools/check-references.sh` puis `bash tools/test-hooks.sh`.

## Revenir à la v2
La v2 (factory centrée sur l'architecture hexagonale) est conservée sous le tag `v2.0` :
```bash
git checkout v2.0          # consulter
git checkout -b retour-v2 v2.0   # repartir de la v2 sur une branche
```

## Principes de conception
1. **Le choix d'architecture est une décision humaine, prise une fois** ; la factory l'applique et le protège.
2. **Une seule source de vérité** : `factory.json` pour le choix, `REFERENCE.md` pour les règles.
3. **Des agents génériques** : on ajoute une architecture sans toucher aux agents.
4. **Les hooks et ArchUnit garantissent, les prompts suggèrent.**
5. **L'humain valide** : la spec et le plan attendent ton accord ; la factory ne pousse et ne merge jamais seule.

Commence par `docs/ROADMAP.md`.
