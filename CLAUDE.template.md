# CLAUDE.md — <NOM_DU_PROJET>

> Modèle de la Claude Factory. **À copier à la racine du projet sous le nom `CLAUDE.md`**, puis à compléter.
> Ne contient que ce qui est propre au projet : les règles communes de la factory sont dans
> `.claude/rules/factory.md` (chargé automatiquement) et l'architecture dans `.claude/factory.json`.
> Garder ce fichier court (< 100 lignes). Supprimer ce paragraphe une fois le fichier rempli.

## Contexte
- Application : <description en une phrase>
- Modules : <liste des modules / bounded contexts prévus>
- Langue du code : anglais. Langue des commentaires métier, specs et messages de commit : français.

## Règles métier de référence
| Code | Règle |
|---|---|
| RM-01 | <règle métier> |

## Stack
- Backend : Java 21, Spring Boot <version>, Spring Security (JWT), Spring Data JPA, Flyway, PostgreSQL, ArchUnit
- Tests : JUnit 5, AssertJ, Mockito, Testcontainers
- Frontend : <Angular x / aucun pour l'instant>

## Structure du dépôt
```
backend/                                   ← code Spring Boot, organisé selon la référence d'architecture
  src/main/java/<package racine>/
  src/main/resources/db/migration/           migrations Flyway V<n>__<description>.sql
  src/test/java/<package racine>/ArchitectureTest.java
docs/specs/                                ← une spec et un plan par fonctionnalité
```

## Sécurité
- <mode d'authentification, rôles, où trouver l'identité de l'utilisateur>

## Environnement local
- Base de données : <PostgreSQL local / docker compose>
- Variables nécessaires : <DB_PASSWORD, JWT_SECRET…> (dans `.env`, jamais commité)

## Commandes
| Action | Commande |
|---|---|
| Compiler le backend | `./mvnw -q compile` (depuis `backend/`) |
| Tests backend | `./mvnw test` (depuis `backend/`) |
| Un seul test | `./mvnw test -Dtest=NomDuTest` (depuis `backend/`) |
| Vérifier l'architecture | `./mvnw test -Dtest=ArchitectureTest` (depuis `backend/`) |
| Lancer l'API | <commande> |
