# Claude Factory — kit de software factory réutilisable

Une « usine logicielle » pilotée par Claude Code pour un stack **Java/Spring Boot + Angular + PostgreSQL**,
avec une **architecture backend au choix**, fixée une fois pour toutes au démarrage de chaque projet.

```
 .claude/factory.json  { "architecture": "couche" | "hexagonal" | … }    ← choisi par l'humain, verrouillé
          │
          ▼
 skill « architecture » → references/<architecture>/REFERENCE.md           ← la seule référence appliquée
          │
          ▼
 /feature "description"
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
   ├─ guard-files / guard-bash : verrou de factory.json, secrets, migrations, git
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
| `.claude/factory.json` | **Le choix d'architecture**, verrouillé |
| `.claude/skills/architecture/` | Aiguilleur (`SKILL.md`) + `references/couche`, `references/hexagonal`, `references/_template` |
| `.claude/skills/` (autres) | `spring-boot-conventions`, `rest-api-design`, `angular-conventions` (communs à toutes les architectures) |
| `.claude/agents/` | 6 sous-agents génériques |
| `.claude/commands/` | `/init-architecture`, `/feature`, `/fix-bug`, `/review-mr` |
| `.claude/hooks/` | `session-start`, `guard-architecture`, `guard-files`, `guard-bash`, `post-edit-check` |
| `tools/check-references.sh` | Vérifie que chaque référence respecte le contrat |
| `tools/test-hooks.sh` | Tests automatiques des hooks (61 scénarios : deux architectures, Windows, verrou, Maven) |
| `docs/ROADMAP.md` | Parcours de montée en compétences |
| `extras/ci/` | **Optionnel, pour plus tard** : exemples GitLab CI et Jenkins |

## Démarrer un projet

```bash
# 1. Prérequis : Claude Code, jq, et sous Windows Git for Windows (les hooks sont des scripts bash)

# 2. Copier le kit à la racine du projet
cp -r claude-factory/.claude  mon-projet/
cp    claude-factory/CLAUDE.template.md mon-projet/CLAUDE.md
chmod +x mon-projet/.claude/hooks/*.sh

# 3. CHOISIR L'ARCHITECTURE — à la main, une seule fois, avant la première session :
#    éditer mon-projet/.claude/factory.json  →  "architecture": "couche"   (ou "hexagonal")

# 4. Compléter CLAUDE.md : uniquement ce qui est propre au projet (contexte, règles métier, commandes)

# 5. Lancer
cd mon-projet && claude
> /init-architecture catalog
> /feature Enregistrer un livre (ISBN unique, titre, auteur, nombre d'exemplaires)
```

Sous Windows, ajoute un `.gitattributes` contenant `*.sh text eol=lf` pour que Git ne convertisse pas les scripts.

## Mettre à jour un projet existant avec une nouvelle version du kit
Le dossier `.claude/` du kit remplace celui du projet, **sauf `factory.json`, qui garde l'architecture choisie** :
```powershell
# depuis la racine du projet, le kit étant cloné à côté (..\factory-dev), à jour sur main
Copy-Item .claude\factory.json $env:TEMP\factory.json.bak
Remove-Item -Recurse -Force .claude\agents, .claude\commands, .claude\hooks, .claude\skills, .claude\rules -ErrorAction SilentlyContinue
Copy-Item -Path ..\factory-dev\.claude\* -Destination .claude -Recurse -Force
Copy-Item $env:TEMP\factory.json.bak .claude\factory.json -Force
Copy-Item ..\factory-dev\.gitattributes . -Force
git add --renormalize .
```
Puis relire le `CHANGELOG.md` : il indique si le `CLAUDE.md` du projet doit être retouché.

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
