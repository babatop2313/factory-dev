# Top Factory — kit de software factory réutilisable

Une « usine logicielle » pilotée par Claude Code pour un stack **Java/Spring Boot + Angular + PostgreSQL**,
avec une **architecture backend au choix**, fixée une fois pour toutes au démarrage de chaque projet.

Depuis la v4, le kit est un **plugin Claude Code** (`top-factory`), distribué par ce dépôt, qui est aussi sa marketplace
(`top`). Le mode « copie » dans `.claude/` reste disponible.

| | Mode plugin (recommandé) | Mode copie |
|---|---|---|
| Où vit le kit | Dans le plugin, partagé par tous les projets | Copié dans `.claude/` de chaque projet |
| Dans le projet | `factory.json`, `stack.json`, `settings.json`, `CLAUDE.md` | Tout le kit + ces fichiers |
| Initialisation | `/top-factory:init`, dans Claude | `install.sh` |
| Mise à jour | Menu `/plugin`, puis `/top-factory:init` si le CHANGELOG le demande | `install.sh` |
| Commandes | `/top-factory:feature` (ou `/feature` s'il n'y a pas de conflit) | `/feature` |

```
 .claude/factory.json  { "architecture": "couche" | "hexagonal" | …, "baseBranch": "develop",
                         "backend": "backend", "frontend": "frontend" }      ← choisi par l'humain, verrouillé
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
| `.claude-plugin/plugin.json` | Manifeste du plugin `top-factory` (nom, **version**) |
| `.claude-plugin/marketplace.json` | Marketplace `top` : ce dépôt distribue le plugin |
| `agents/` | 6 sous-agents génériques |
| `commands/` | `/init` (mode plugin), `/init-architecture`, `/update-architecture-test`, `/feature`, `/dashboard`, `/add-frontend`, `/add-integration`, `/add-mcp-server`, `/fix-bug`, `/review-mr` |
| `skills/architecture/` | Aiguilleur + `references/couche`, `references/hexagonal`, `references/_template` |
| `skills/conventions/` | Socle non négociable, profil `top`, options (mapping, lombok, errors, ids ; front-ui, front-forms) |
| `skills/integrations/` | Une référence par technologie (postgresql, redis, mail, stockage-objet, rabbitmq, kafka) + vocabulaire des rôles |
| `skills/angular-conventions/` | Socle frontend (structure, dépendances, authentification, erreurs, tests) + `rules.conf` |
| `skills/` (autres) | `rest-api-design` |
| `hooks/hooks.json`, `hooks/scripts/` | Déclaration des hooks et scripts : `session-start`, `guard-architecture`, `guard-frontend`, `guard-files`, `events`, `dashboard`, `guard-bash`, `guard-mcp-sql`, `post-edit-check`, `post-bash-check` |
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

**Dans chaque projet** : `.claude/factory.json` (architecture, branche d'intégration, dossiers backend et frontend, **verrouillés**), `.claude/stack.json`
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
/plugin marketplace add babatop2313/top-factory
/plugin install top-factory@top
```
Le dépôt peut être privé : Claude Code utilise alors vos identifiants Git (GitHub).

**2. Créer le projet** : un dépôt Git avec un backend Spring Boot (start.spring.io), dans le dossier de votre choix
(`backend/`, `library-api/`, ou à la racine).

**3. Initialiser la factory**, dans Claude, à la racine du projet :
```
/top-factory:init
```
Claude détecte le backend (`pom.xml` Spring Boot) et le frontend (`angular.json`), vous demande l'architecture, la branche
d'intégration et les intégrations, récapitule, puis lance le script du kit, qui crée `.claude/factory.json`
(**verrouillé**), `.claude/stack.json`, `.claude/settings.json` (permissions du kit, activation du plugin) et `CLAUDE.md`,
et complète `.gitattributes`. Un plugin ne peut pas fournir de règles de permission : c'est pourquoi le script les écrit
dans le projet. La forme courte `/init` est celle de la commande intégrée de Claude Code : tapez le nom complet.

**4. Relancer Claude**, compléter `CLAUDE.md`, puis :
```
> /top-factory:init-architecture catalog
> /top-factory:feature Enregistrer un livre (ISBN unique, titre, auteur, nombre d'exemplaires)
```
Les commandes d'un plugin sont préfixées par son nom ; la forme courte (`/feature`) fonctionne tant qu'aucune autre
commande ne porte le même nom.

**Sans Claude** (CI, autre outil) : le même script fait tout, `--detect` montre ce qu'il trouverait sans rien écrire :
```bash
bash top-factory/tools/install.sh mon-projet --detect
bash top-factory/tools/install.sh mon-projet --architecture hexagonal --mode plugin \
     [--backend library-api] [--frontend web] [--integrations postgresql,redis] [--base-branch main]
```
Windows (PowerShell) : `bash` seul lance **WSL** ; utiliser `& "C:\Program Files\Git\bin\bash.exe" …` ou Git Bash.

**Mode copie** (sans plugin) : le script sans `--mode plugin` copie le kit dans `.claude/` (commandes sans préfixe,
pas de commande `init`, qui entrerait en conflit avec `/init` de Claude Code).

## Mettre à jour
**Mode plugin** :
1. Dans Claude Code : `/plugin marketplace update top`, puis mettre à jour le plugin `top-factory` depuis le menu
   `/plugin`, et relancer Claude Code (ou `/reload-plugins`). Le démarrage annonce la nouvelle version.
2. Si le `CHANGELOG.md` le demande (« À faire dans un projet existant ») : `/top-factory:init` (mise à jour : aucune
   question sur l'architecture), puis `/top-factory:update-architecture-test` si l'`ArchitectureTest` a changé.

**Mode copie** : `git pull` dans le dépôt du kit, puis `bash top-factory/tools/install.sh mon-projet`.

**Passer un projet du mode copie au mode plugin** : `bash top-factory/tools/install.sh mon-projet --mode plugin`.
Le script retire de `.claude/` les fichiers copiés du kit, conserve ceux propres au projet (agents ou skills maison,
qui s'ajoutent au plugin), et réécrit `settings.json` sans les hooks (le plugin les fournit). À faire dans une branche dédiée.

Dans tous les cas, le script refuse tout changement d'architecture et de dossier backend ou frontend déjà déclaré,
conserve `factory.json` et `stack.json`, et ne touche ni à `settings.local.json` ni au `CLAUDE.md` du projet.

## Modifier le plugin
Le plugin, c'est ce dépôt. On le modifie comme avant :
1. Branche, modifications, `bash tools/check-references.sh`, `bash tools/test-hooks.sh copy` et `bash tools/test-hooks.sh plugin`.
2. **Tester en local sans rien publier** : `claude --plugin-dir ../top-factory` depuis un projet charge directement
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

## Tableau de bord et notifications
Chaque projet initialisé est suivi automatiquement, sans rien à lancer : les hooks de Claude Code (`SessionStart`,
`SubagentStart`/`SubagentStop`, `Stop`, `Notification`, commits et pushes) écrivent un journal dans
`~/.top-factory/events/` et inscrivent le projet dans `~/.top-factory/projects.json`.

- **`/top-factory:dashboard`** ouvre `~/.top-factory/dashboard.html` : une page locale, sans serveur, actualisée toutes
  les 15 secondes, avec trois vues — **Vue d'ensemble** (ce qui attend une action de ta part, features en cours,
  activité), **Projets** (pour chacun, le **process de la feature** étape par étape : spec, plan, code, tests, revue,
  commit, PR, avec les validations attendues) et **Documentation** (principe, workflow, toutes les commandes et tous les
  agents, lus dans le kit installé, garde-fous, dépannage).
- **Notifications** à chaque validation requise, autorisation demandée ou fin de tâche : notification du système
  (Windows, macOS, Linux) et, en option, sur le téléphone avec **ntfy** (`/top-factory:dashboard notifications`).
  Elles ne contiennent que le projet, l'étape et la branche, jamais de code ni de texte de Claude.
- Réglages : `~/.top-factory/config.json` (créé au premier événement) ; dossier personnalisable avec `TOP_FACTORY_HOME`.

## Frontend Angular
Un projet démarre souvent sans frontend (`"frontend": null` dans `factory.json`). **`/top-factory:add-frontend`** le crée :
- vous choisissez le **dossier**, le **nom** de l'application et la **version d'Angular** (`latest` ou une version majeure) ;
- la commande installe la bibliothèque d'interface de l'option `front-ui` (profil `top` : **PrimeNG**, avec la grille et
  les utilitaires de **Bootstrap**), `angular-eslint`, le proxy de développement (`/api` → `localhost:8080`) et la
  structure `core/` · `shared/` · `features/`, puis déclare le dossier dans `factory.json` (par le script) ;
- l'authentification et les écrans métier viennent ensuite par `/top-factory:feature`, à partir du contrat d'API.

Garde-fous : après chaque `.ts`, **vérification des types** (`tsc --noEmit`) et **règles de dépendance**
(`guard-frontend` : aucune feature n'en importe une autre, `HttpClient` seulement dans les services, jeton jamais dans
`localStorage`, aucune URL d'API absolue). Les agents lancent `ng build`, le lint et les tests avant de rendre la main.

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
| `/top-factory:init` | n'écrit rien lui-même : il appelle `install.sh`, qui ne change jamais une architecture ni un dossier déjà déclarés |

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
