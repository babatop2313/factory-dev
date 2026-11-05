# CLAUDE.md — <NOM_DU_PROJET>

> Mémoire du projet, lue par Claude à chaque session. Garde-la courte (< 150 lignes) :
> les conventions détaillées sont dans `.claude/skills/`.

## Contexte
- Application : <description en une phrase>
- Langue du code : anglais. Langue des commentaires métier, specs et messages de commit : français.

## Stack
- Backend : Java 21, Spring Boot, Spring Security (JWT), Spring Data JPA, Flyway, PostgreSQL 16, ArchUnit
- Frontend : Angular 18+ (standalone components, signals), Angular Material
- Build / qualité : Maven, npm, SonarQube, Docker

## Architecture backend
- **L'architecture est choisie une seule fois, au démarrage du projet, dans `.claude/factory.json`** (champ `architecture`).
  Elle ne change jamais en cours de développement.
- Les règles complètes sont dans `.claude/skills/architecture/references/<architecture>/REFERENCE.md`.
  Leur résumé est injecté au début de chaque session par le hook `session-start.sh`.
- Avant **toute** tâche backend (conception, code, tests, revue, bug) : charger le skill `architecture`
  et lire la référence active. N'utiliser aucune autre référence.
- Ne jamais modifier `.claude/factory.json` (verrouillé par un hook et une règle de permission).

## Structure du dépôt
```
backend/                                   ← code Spring Boot, organisé selon la référence d'architecture
  src/main/resources/db/migration/           migrations Flyway V<n>__<description>.sql
  src/test/java/.../ArchitectureTest.java    règles ArchUnit de l'architecture (ne jamais supprimer ni modifier)
frontend/  src/app/{core,shared,features/<feature>}
docs/specs/                                ← une spec par fonctionnalité
```

## Commandes
| Action | Commande |
|---|---|
| Compiler le backend | `cd backend && ./mvnw -q compile` |
| Tests backend | `cd backend && ./mvnw test` |
| Un seul test | `cd backend && ./mvnw test -Dtest=NomDuTest` |
| Vérifier l'architecture | `cd backend && ./mvnw test -Dtest=ArchitectureTest` |
| Lint frontend | `cd frontend && npm run lint` |
| Tests frontend | `cd frontend && npm test -- --watch=false` |
| Stack locale | `docker compose up -d` |

## Règles non négociables
- Respecter la règle de dépendance de la référence d'architecture active. Une violation est toujours bloquante.
- Jamais d'entité JPA exposée par un contrôleur : toujours des DTO.
- Toute modification de schéma passe par une nouvelle migration Flyway ; ne jamais modifier une migration existante.
- Pas de secret dans le code ni dans `application.yml` : variables d'environnement.
- Toute règle métier est testée, dans la couche où la référence place la logique métier.
- `ArchitectureTest` doit toujours passer ; on corrige le code, jamais les règles.
- Ne jamais pousser sur `main`/`develop` ni merger : on produit une branche et une MR.

## Workflow attendu
1. Lire la spec dans `docs/specs/` (ou la faire écrire par l'agent `spec-writer`).
2. Plan validé par l'humain avant d'écrire du code.
3. Implémentation dans l'ordre d'implémentation de la référence d'architecture.
4. Tests → revue par l'agent `reviewer` → corrections.
5. Commit au format Conventional Commits : `feat(catalog): enregistrement d'un livre`.
