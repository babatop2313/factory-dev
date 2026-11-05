# CLAUDE.md — <NOM_DU_PROJET>

> Mémoire du projet, lue par Claude à chaque session. Garde-la courte (< 150 lignes) :
> les conventions détaillées sont dans `.claude/skills/`.

## Contexte
- Application : <description en une phrase>
- Langue du code : anglais. Langue des commentaires métier, specs et messages de commit : français.

## Stack
- Backend : Java 21, Spring Boot 3.x, Spring Security (JWT), Spring Data JPA, Flyway, PostgreSQL 16, Redis, ArchUnit
- Frontend : Angular 18+ (standalone components, signals), Angular Material
- Build / qualité : Maven, npm, SonarQube, Docker

## Architecture backend : hexagonale (ports & adapters) + clean architecture
Détail complet et exemples : skill `hexagonal-architecture`. À charger avant toute tâche backend.

```
backend/src/main/java/<groupId>/<boundedContext>/
  domain/                      ← cœur métier, Java pur, AUCUNE dépendance framework
    model/                       agrégats, entités, value objects
    exception/                   exceptions métier
    service/                     règles métier qui couvrent plusieurs agrégats
  application/                 ← cas d'utilisation, dépend uniquement de domain
    port/in/                     interfaces des use cases + Command / Query
    port/out/                    interfaces vers l'extérieur (persistance, notification…)
    usecase/                     implémentations des use cases (@UseCase)
  adapter/                     ← tout ce qui touche à la technique
    in/web/                      contrôleurs REST, DTO request/response, mapper web
    out/persistence/             entités JPA, repositories Spring Data, mapper, adapter
    out/<autre>/                 Redis, SMS, API externes…
  config/                      ← câblage Spring du bounded context
<groupId>/shared/              ← @UseCase, types transverses (aucune logique métier)
backend/src/main/resources/db/migration/   ← migrations Flyway V<n>__<description>.sql
backend/src/test/java/.../ArchitectureTest.java   ← règles ArchUnit (ne jamais supprimer)
frontend/  src/app/{core,shared,features/<feature>}
docs/specs/                                ← une spec par fonctionnalité
```

**Règle de dépendance** : `adapter → application → domain`. Jamais l'inverse.
- `domain` n'importe ni `org.springframework`, ni `jakarta.persistence`, ni `jakarta.validation`, ni `lombok`.
- `application` n'importe jamais `adapter` ni `config`, et pas de JPA.
- Les adapters ne se parlent pas entre eux : ils passent par un port.

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
- Le domaine ne connaît ni la base, ni HTTP, ni Spring. Une règle métier dans un contrôleur ou un adapter est une erreur.
- Une entité JPA n'est jamais un objet du domaine : deux classes distinctes + mapper dans l'adapter.
- Un contrôleur n'appelle qu'un port d'entrée (use case), jamais un repository ni une classe du domaine directement.
- Toute modification de schéma passe par une nouvelle migration Flyway ; ne jamais modifier une migration existante.
- Pas de secret dans le code ni dans `application.yml` : variables d'environnement.
- Tests : domaine en tests unitaires purs, use cases avec des ports simulés, adapters en tests d'intégration.
- `ArchitectureTest` doit toujours passer.
- Ne jamais pousser sur `main`/`develop` ni merger : on produit une branche et une MR.

## Workflow attendu
1. Lire la spec dans `docs/specs/` (ou la faire écrire par l'agent `spec-writer`).
2. Plan validé par l'humain avant d'écrire du code.
3. Implémentation de l'intérieur vers l'extérieur : domaine → application → adapters → config.
4. Tests → revue par l'agent `reviewer` → corrections.
5. Commit au format Conventional Commits : `feat(loan): ajout de l'emprunt d'un livre`.
