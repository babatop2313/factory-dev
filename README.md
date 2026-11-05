# Claude Factory — kit de software factory réutilisable

Une « usine logicielle » pilotée par Claude Code pour un stack **Java/Spring Boot + Angular + PostgreSQL**,
avec un backend imposé en **architecture hexagonale (ports & adapters) + clean architecture**.
Pensée pour être copiée dans n'importe quel projet et pour apprendre progressivement.

```
 Besoin
   │
   ▼
 /feature "description"                       ← commande d'orchestration
   │
   ├─► spec-writer   → docs/specs/<feature>.md (règles RM-xx, critères d'acceptation)
   ├─► architect     → plan par couche : domaine / ports / use cases / adapters
   ├─► backend-dev   → domaine → application → adapters → config (de l'intérieur vers l'extérieur)
   ├─► frontend-dev  → Angular
   ├─► test-writer   → tests par couche + ArchUnit
   └─► reviewer      → revue : architecture d'abord, puis sécurité, perf, tests (lecture seule)
   │
   ▼
 Garde-fous automatiques
   ├─ hooks   : règle de dépendance vérifiée à chaque écriture, compilation, actions dangereuses bloquées
   └─ ArchUnit: ArchitectureTest vérifie la règle de dépendance sur tout le code
```

## Architecture backend imposée
```
<boundedContext>/
  domain/        Java pur : agrégats, value objects, services et exceptions métier
  application/   port/in (use cases), port/out (besoins vers l'extérieur), usecase (implémentations)
  adapter/       in/web (REST), out/persistence (JPA), out/<autre> (Redis, SMS…)
  config/        câblage Spring
```
Les dépendances vont toujours vers l'intérieur : `adapter → application → domain`.
Tout est détaillé, avec exemples de code et règles ArchUnit, dans `.claude/skills/hexagonal-architecture/SKILL.md`.

## Contenu

| Élément | Rôle |
|---|---|
| `CLAUDE.md` | Mémoire projet : stack, architecture, commandes, règles. **À adapter à chaque projet.** |
| `.claude/agents/` | 6 sous-agents spécialisés (contexte isolé, outils restreints) |
| `.claude/skills/` | `hexagonal-architecture`, `spring-boot-conventions`, `rest-api-design`, `angular-conventions` |
| `.claude/commands/` | `/init-hexagonal`, `/feature`, `/fix-bug`, `/review-mr` |
| `.claude/hooks/` | Garde-fous : architecture, fichiers sensibles, migrations, git, compilation |
| `.claude/settings.json` | Permissions + déclaration des hooks |
| `docs/ROADMAP.md` | Parcours de montée en compétences en 6 niveaux, exercices pas à pas |
| `extras/ci/` | **Optionnel, pour plus tard** : exemples GitLab CI et Jenkins |

## Installation dans un projet

```bash
# 1. Installer Claude Code (une fois)
curl -fsSL https://claude.ai/install.sh | bash

# 2. Prérequis des hooks : jq
sudo apt install jq   # ou brew install jq

# 3. Copier le kit à la racine du projet
cp -r claude-factory/.claude  mon-projet/
cp    claude-factory/CLAUDE.md mon-projet/
chmod +x mon-projet/.claude/hooks/*.sh

# 4. Adapter CLAUDE.md (nom du projet, package racine, commandes)

# 5. Préparer l'architecture puis lancer une première fonctionnalité
cd mon-projet && claude
> /init-hexagonal catalog
> /feature Enregistrer un livre (ISBN unique, titre, auteur, nombre d'exemplaires)
```

Le dossier `extras/` n'est pas à copier : la factory fonctionne entièrement sans CI.

Pour réutiliser les agents et skills génériques dans **tous** tes projets sans copie : place-les dans
`~/.claude/agents/` et `~/.claude/skills/`. Garde dans chaque projet uniquement ce qui lui est propre.

## Principes de conception

1. **Le métier au centre** : le domaine ne dépend d'aucun framework ; la technique se branche autour via des ports.
2. **Une responsabilité par agent** : la description dit *quand* l'utiliser, c'est elle qui déclenche la délégation.
3. **Moindre privilège** : architecte et reviewer en lecture seule, seuls les devs écrivent.
4. **Les hooks et ArchUnit garantissent, les prompts suggèrent** : ce qui doit *toujours* être vrai est vérifié automatiquement.
5. **L'humain valide** : la spec et le plan attendent ton accord ; la factory ne pousse et ne merge jamais seule.
6. **CLAUDE.md court** : le détail vit dans les skills, chargés seulement quand c'est utile.

Commence par `docs/ROADMAP.md`.
