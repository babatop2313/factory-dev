# Claude Factory — kit de software factory réutilisable

Une « usine logicielle » pilotée par Claude Code pour un stack **Java/Spring Boot + Angular + PostgreSQL**,
avec une **architecture backend au choix**, fixée une fois pour toutes au démarrage de chaque projet.

Depuis la v4, le kit est un **plugin Claude Code** (`factory`), distribué par ce dépôt, qui est aussi sa marketplace
(`factory-dev`). Le mode « copie » dans `.claude/` reste disponible.

| | Mode plugin (recommandé) | Mode copie |
|---|---|---|
| Où vit le kit | Dans le plugin, partagé par tous les projets | Copié dans `.claude/` de chaque projet |
| Dans le projet | `factory.json`, `stack.json`, `settings.json`, `CLAUDE.md` | Tout le kit + ces fichiers |
| Mise à jour | Menu `/plugin`, puis `install.sh --mode plugin` si le CHANGELOG le demande | `install.sh` |
| Commandes | `/factory:feature` (ou `/feature` s'il n'y a pas de conflit) | `/feature` |

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
- **Des règles communes chargées automatiquement** : `rules/factory.md` du kit, copié dans `.claude/rules/` (mode copie)
  ou injecté par le hook `SessionStart` (mode plugin, qui ne peut pas fournir de règles) ; le `CLAUDE.md` du projet ne
  contient que ce qui lui est propre. Le hook annonce aussi le dossier du kit, noté `<kit>` dans les agents et commandes.

## Contenu du dépôt

| Élément | Rôle |
|---|---|
| `.claude-plugin/plugin.json` | Manifeste du plugin `factory` (nom, **version**) |
| `.claude-plugin/marketplace.json` | Marketplace `factory-dev` : ce dépôt distribue le plugin |
| `agents/` | 6 sous-agents génériques |
| `commands/` | `/init-architecture`, `/update-architecture-test`, `/feature`, `/add-integration`, `/add-mcp-server`, `/fix-bug`, `/review-mr` |
| `skills/architecture/` | Aiguilleur + `references/couche`, `references/hexagonal`, `references/_template` |
| `skills/conventions/` | Socle non négociable, profil `top`, options (mapping, lombok, errors, ids) |
| `skills/integrations/` | Une référence par technologie (postgresql, redis, mail, stockage-objet, rabbitmq, kafka) + vocabulaire des rôles |
| `skills/` (autres) | `rest-api-design`, `angular-conventions` |
| `hooks/hooks.json`, `hooks/scripts/` | Déclaration des hooks et scripts : `session-start`, `guard-architecture`, `guard-files`, `guard-bash`, `guard-mcp-sql`, `post-edit-check`, `post-bash-check` |
| `rules/factory.md` | Règles communes de la factory |
| `templates/` | Fichiers créés dans chaque projet : `factory.json`, `stack.json`, `settings.json` (permissions) |
| `CLAUDE.template.md` | Modèle du `CLAUDE.md` d'un projet |
| `CLAUDE.md` (racine) | Instructions pour travailler **sur le kit lui-même** |
| `tools/install.sh` | Prépare ou met à jour un projet, en mode `plugin` ou `copy` (Linux, macOS, Windows avec Git Bash) |
| `tools/check-references.sh` | Contrat des architectures, intégrations, conventions et du plugin |
| `tools/test-hooks.sh` | Tests des hooks, dans les deux modes |
| `.github/workflows/factory-ci.yml` | CI sur **Ubuntu, macOS et Windows** à chaque PR |
| `docs/` | `ROADMAP.md`, `ROADMAP-MCP.md`, `ROADMAP-v4.md` |
| `extras/ci/`, `extras/mcp/` | **Optionnels** : exemples de CI, serveurs MCP (GitHub, PostgreSQL en lecture seule) |

**Dans chaque projet** : `.claude/factory.json` (architecture et branche d'intégration, **verrouillés**), `.claude/stack.json`
(stack, modifiable avec accord), `.claude/settings.json` (permissions du kit et activation du plugin ; fichier du kit,
réécrit à chaque mise à jour — les réglages personnels vont dans `.claude/settings.local.json`) et `CLAUDE.md`.

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

## Démarrer un projet (mode plugin)
**1. Installer le plugin**, une fois par poste, dans Claude Code :
```
/plugin marketplace add babatop2313/factory-dev
/plugin install factory@factory-dev
```
Le dépôt peut être privé : Claude Code utilise alors vos identifiants Git (GitHub).

**2. Préparer le projet** avec le script du kit, cloné à côté du projet (`factory-dev/` et `mon-projet/` dans le même dossier) :
```bash
bash factory-dev/tools/install.sh mon-projet --architecture hexagonal --mode plugin   # ou couche ; --base-branch main si besoin
```
**Windows (PowerShell)** : dans PowerShell, `bash` seul lance **WSL** (erreur `execvpe(/bin/bash) failed`) ;
utiliser le chemin complet du bash de Git, ou une fenêtre Git Bash :
```powershell
& "C:\Program Files\Git\bin\bash.exe" factory-dev/tools/install.sh mon-projet --architecture hexagonal --mode plugin
```
Le script crée `.claude/factory.json` (architecture et branche d'intégration, **verrouillés**), `.claude/stack.json`,
`.claude/settings.json` (permissions du kit ; il invite aussi les autres membres de l'équipe à installer le plugin)
et `CLAUDE.md` (à compléter), et complète `.gitattributes`. Un plugin ne peut pas fournir de règles de permission :
c'est pourquoi le script les écrit dans le projet.

**3. Dans Claude**, à la racine du projet :
```
> /factory:init-architecture catalog
> /factory:feature Enregistrer un livre (ISBN unique, titre, auteur, nombre d'exemplaires)
```
Les commandes d'un plugin sont préfixées par son nom ; la forme courte (`/feature`) fonctionne tant qu'aucune autre
commande ne porte le même nom.

**Mode copie** (sans plugin) : même script sans `--mode plugin`. Le kit est alors copié dans `.claude/`.

## Mettre à jour
**Mode plugin** :
1. Dans Claude Code : `/plugin marketplace update factory-dev`, puis mettre à jour le plugin `factory` depuis le menu
   `/plugin`, et relancer Claude Code (ou `/reload-plugins`). Le démarrage annonce la nouvelle version.
2. Si le `CHANGELOG.md` le demande (« À faire dans un projet existant ») : `bash factory-dev/tools/install.sh mon-projet --mode plugin`
   pour réécrire `.claude/settings.json`, puis `/factory:update-architecture-test` si l'`ArchitectureTest` a changé.

**Mode copie** : `cd factory-dev && git pull && cd .. && bash factory-dev/tools/install.sh mon-projet`.

**Passer un projet du mode copie au mode plugin** : `bash factory-dev/tools/install.sh mon-projet --mode plugin`.
Le script retire de `.claude/` les fichiers copiés du kit, conserve ceux propres au projet (agents ou skills maison,
qui s'ajoutent au plugin), et réécrit `settings.json` sans les hooks (le plugin les fournit). À faire dans une branche dédiée.

Dans tous les cas, le script refuse tout changement d'architecture, conserve `factory.json` et `stack.json`, et ne touche
ni à `settings.local.json` ni au `CLAUDE.md` du projet.

## Modifier le plugin
Le plugin, c'est ce dépôt. On le modifie comme avant :
1. Branche, modifications, `bash tools/check-references.sh`, `bash tools/test-hooks.sh copy` et `bash tools/test-hooks.sh plugin`.
2. **Tester en local sans rien publier** : `claude --plugin-dir ../factory-dev` depuis un projet charge directement
   la copie de travail du plugin (relancer Claude, ou `/reload-plugins`, après chaque modification).
3. Monter la version dans `.claude-plugin/plugin.json`, noter le changement dans `CHANGELOG.md`, PR, fusion, tag.
4. Chaque poste récupère la nouvelle version avec la mise à jour du plugin.

Les fichiers du plugin installé (dans le cache de Claude Code) ne se modifient pas à la main : ils sont remplacés à
chaque mise à jour. Une adaptation propre à un projet va dans le `.claude/` de ce projet (agent, skill ou commande
supplémentaire), à côté du plugin.

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
| redis | `sortant-cache` | **testée** (Bibliothèque, v3.4.1) |
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
| Règle `deny` dans `.claude/settings.json` du projet | double protection sur l'édition |
| Marqueur `// architecture: <nom>` en tête d'`ArchitectureTest.java` | `session-start.sh` signale toute incohérence avec `factory.json` |
| `/init-architecture` | refuse d'initialiser un projet déjà initialisé avec une autre architecture |

Ces protections empêchent Claude et les erreurs de manipulation de changer l'architecture.
Un humain peut toujours éditer les fichiers à la main : changer d'architecture reste une décision humaine et consciente.

## Ajouter une architecture
1. Copier `skills/architecture/references/_template/` vers `references/<nom>/`.
2. Remplir les 5 fichiers : `REFERENCE.md` (9 sections, titres exacts), `ArchitectureTest.java`
   (première ligne `// architecture: <nom>`), `rules.conf`, `roles.conf`, `scaffold.md`.
3. Vérifier : `bash tools/check-references.sh` puis `bash tools/test-hooks.sh copy` et `plugin`.

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
