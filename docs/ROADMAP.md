# Parcours de montée en compétences — Claude Factory

Six niveaux, chacun découpé en exercices pas à pas. Chaque exercice donne :
**l'objectif**, **les étapes** (avec les prompts exacts à taper), **ce qu'il faut observer**, **le résultat attendu**,
**une checklist de validation** et **les pièges fréquents**.

Règles du jeu :
- Fais les exercices **dans l'ordre** : chaque niveau s'appuie sur le précédent.
- Travaille sur le **projet bac à sable** décrit au niveau 0, jamais sur un projet client.
- Tiens un fichier `docs/journal.md` : pour chaque exercice, note ce qui a marché, ce qui a raté et ce que tu as changé.
  C'est ce journal qui transforme les exercices en compétences.
- Un commit Git par exercice terminé (`git tag niveau-1.2` par exemple) : tu peux toujours revenir en arrière.

La CI (GitLab, Jenkins) n'est **pas** dans ce parcours : elle est en annexe, à aborder plus tard.

---

## Niveau 0 — Le projet bac à sable « Bibliothèque » (½ journée)

### Le domaine
Une bibliothèque prête des livres à ses membres. Deux bounded contexts :
- **catalog** : les livres (ISBN, titre, auteur, nombre d'exemplaires).
- **loan** : les emprunts.

Règles métier que tu implémenteras au fil des exercices :

| Code | Règle |
|---|---|
| RM-01 | Un membre a au maximum **3 emprunts actifs**. |
| RM-02 | Un membre qui a un emprunt **en retard** ne peut pas emprunter. |
| RM-03 | Un emprunt dure **14 jours**. |
| RM-04 | On ne peut emprunter un livre que s'il reste un exemplaire disponible. |
| RM-05 | Un livre rendu redevient disponible ; on ne rend pas deux fois le même emprunt. |
| RM-06 | Un emprunt peut être **prolongé une seule fois** de 7 jours, s'il n'est pas en retard. |
| RM-07 | L'ISBN d'un livre est unique et valide (13 chiffres). |

### Étapes
1. Crée le dossier `bibliotheque/` avec deux sous-dossiers `backend/` et `frontend/`.
2. Génère le backend avec Spring Initializr (Maven, Java 21, Spring Boot 3.x) et ces dépendances :
   Spring Web, Spring Data JPA, PostgreSQL Driver, Flyway Migration, Validation, Spring Security, OAuth2 Resource Server, Lombok, Testcontainers.
   Package racine : `com.example.library`.
3. Génère le frontend : `npx @angular/cli new frontend --standalone --routing --style=scss`.
4. Ajoute un `docker-compose.yml` à la racine avec un service PostgreSQL 16 (base `library`, port 5432).
5. Vérifie : `cd backend && ./mvnw test` passe, `cd frontend && npm start` affiche la page Angular.
6. `git init`, premier commit.
7. Copie le kit : `cp -r claude-factory/.claude bibliotheque/` et `chmod +x bibliotheque/.claude/hooks/*.sh`.
   **Ne copie pas encore `CLAUDE.template.md`** : c'est l'objet de l'exercice 1.1.
   Pour l'exercice 1.1, retire aussi temporairement `.claude/rules/factory.md` (mets-le de côté), sinon les règles communes
   s'appliquent déjà. Remets-le à l'étape 6 de l'exercice.
8. **Choisis l'architecture**, à la main, dans `bibliotheque/.claude/factory.json` :
   `"architecture": "hexagonal"` (les exercices du niveau 2 sont écrits pour elle) ou `"couche"` (voir la variante en fin de niveau 2).
   Ce choix est définitif pour ce projet.

### Checklist
- [ ] Le backend compile et ses tests passent.
- [ ] PostgreSQL tourne (`docker compose ps`).
- [ ] `jq --version` répond (nécessaire aux hooks).
- [ ] `claude` se lance à la racine de `bibliotheque/`.

---

## Niveau 1 — CLAUDE.md : la mémoire du projet (1 jour)

**Concept** : Claude relit `CLAUDE.md` au début de chaque session. Tout ce qui y est écrit n'a plus besoin d'être répété dans tes prompts.

### Exercice 1.1 — Mesurer l'effet de CLAUDE.md
**Objectif** : constater par toi-même ce que Claude fait *sans* consignes, pour comprendre ce que CLAUDE.md change.

Étapes :
1. Assure-toi qu'il n'y a **pas** de `CLAUDE.md` à la racine. Lance `claude`.
2. Tape exactement :
   ```
   Ajoute dans le backend la possibilité d'enregistrer un livre (ISBN, titre, auteur, nombre d'exemplaires) via une API REST.
   ```
3. Laisse Claude terminer, **ne corrige rien**. Fais `git diff --stat` et regarde le code.
4. Note dans `docs/journal.md` :
   - Où est l'entité ? Porte-t-elle `@Entity` ?
   - Le contrôleur appelle-t-il directement un repository ?
   - Où est vérifiée l'unicité de l'ISBN (RM-07) ?
   - Y a-t-il une migration Flyway ? Des tests ?
5. Annule tout : `git checkout . && git clean -fd`.
6. Copie maintenant `CLAUDE.template.md` du kit à la racine sous le nom `CLAUDE.md`, remplace `<NOM_DU_PROJET>` par `Bibliothèque`
   et la description par une phrase sur le domaine. Relance `claude`, retape **le même prompt**.
7. Compare les deux résultats ligne à ligne dans ton journal.

Résultat attendu : la deuxième version range le code dans `domain/`, `application/`, `adapter/`,
avec un use case `RegisterBookUseCase`, une entité JPA distincte de l'objet métier et une migration Flyway.

Checklist :
- [ ] Le journal liste au moins 4 différences concrètes entre les deux versions.
- [ ] Tu sais dire quelle ligne de `CLAUDE.md` a provoqué chaque différence.

Vérifie ce qui est chargé avec `/context` : la liste « Memory files » doit montrer `CLAUDE.md` et `.claude/rules/factory.md`.

Pièges : Claude ne relit `CLAUDE.md` qu'au démarrage d'une session. Après l'avoir modifié, relance `claude` (ou démarre une nouvelle conversation).

### Exercice 1.2 — `/init` et fusion
**Objectif** : savoir produire un `CLAUDE.md` pour un projet existant.

Étapes :
1. Renomme ton `CLAUDE.md` en `CLAUDE.kit.md`.
2. Dans `claude`, tape `/init`. Claude analyse le projet et génère un `CLAUDE.md`.
3. Compare avec `CLAUDE.kit.md` : qu'a-t-il trouvé tout seul (commandes Maven, structure) ? Qu'a-t-il raté (règles d'architecture, règles de l'équipe) ?
4. Fusionne : garde les commandes détectées par `/init` et les règles du kit. Supprime `CLAUDE.kit.md`.

Checklist :
- [ ] Un seul `CLAUDE.md`, moins de 150 lignes.
- [ ] Les commandes listées fonctionnent toutes quand tu les copies-colles dans un terminal.

### Exercice 1.3 — Ajouter une règle et la prouver
**Objectif** : apprendre à écrire une règle que Claude applique vraiment.

Étapes :
1. Ajoute dans « Règles non négociables » :
   `- Les identifiants métier sont des value objects (record) : jamais de UUID ou de Long nu dans le domaine.`
2. Relance `claude`, puis :
   ```
   Ajoute au catalogue un use case pour consulter un livre par son identifiant.
   ```
3. Vérifie que la signature du use case utilise `BookId` et non `UUID`.
4. Si ce n'est pas le cas : reformule la règle (plus précise, avec un exemple) et recommence. Note dans le journal la formulation qui a fonctionné.

Checklist :
- [ ] La règle est appliquée sans que tu l'aies rappelée dans le prompt.

---

## Niveau 2 — L'architecture avec Claude (2 jours)

**Concept** : avant d'automatiser, il faut savoir guider Claude couche par couche et reconnaître une violation d'architecture.
L'architecture n'est pas codée dans les agents : elle vient de `.claude/factory.json` et de la référence
`.claude/skills/architecture/references/<architecture>/REFERENCE.md`.

Les exercices 2.1 à 2.3 sont écrits pour l'architecture **hexagonale**. Si ton projet est en **couches**,
suis la « Variante couche » à la fin du niveau.

### Exercice 2.0 — Comprendre le choix et le verrou
1. Ouvre `.claude/factory.json`, puis lis `.claude/skills/architecture/SKILL.md` et la référence active en entier.
2. Lance `claude`. Le message de démarrage injecté par le hook `session-start.sh` doit annoncer l'architecture du projet.
   Demande : `Quelle architecture dois-tu respecter et où sont ses règles ?`
3. Demande : `Passe le projet en architecture en couches, ce sera plus simple.`
   Attendu : Claude refuse ; s'il tente de modifier `factory.json`, le hook `guard-files.sh` le bloque.
4. Lance `bash tools/check-references.sh` depuis le dépôt du kit : toutes les références doivent respecter le contrat.

Checklist :
- [ ] Tu sais dire quel fichier fixe l'architecture et quels garde-fous l'empêchent de changer.
- [ ] Tu sais nommer les 9 sections obligatoires d'une référence et quel agent lit laquelle.

### Exercice 2.1 — Initialiser l'architecture
Étapes :
1. Dans `claude` :
   ```
   /init-architecture catalog
   ```
2. Lis tout ce qui a été créé : `shared/UseCase.java`, `ArchitectureTest.java` (première ligne `// architecture: hexagonal`), les `package-info.java`.
3. Lance toi-même `cd backend && ./mvnw test -Dtest=ArchitectureTest`.

Résultat attendu : arborescence `catalog/{domain,application,adapter,config}` vide mais documentée, `ArchitectureTest` vert.

Checklist :
- [ ] Tu sais expliquer chacune des 4 règles d'`ArchitectureTest` avec tes mots (écris-le dans le journal).
- [ ] Tu sais pourquoi `archunit.properties` contient `failOnEmptyShould=false`.

### Exercice 2.2 — Construire un use case couche par couche, à la main
**Objectif** : piloter Claude finement, une couche à la fois, et valider chaque étape. C'est ce que fera l'agent `backend-dev` plus tard.

Use case : **enregistrer un livre** (RM-07). Tape les prompts **un par un**, et relis le code entre chaque étape.

1. Domaine :
   ```
   Charge le skill architecture. Dans catalog/domain, crée le value object Isbn (13 chiffres, sinon InvalidIsbnException),
   le value object BookId et l'agrégat Book (isbn, titre, auteur, nombre d'exemplaires >= 1) avec une méthode de fabrique register(...)
   et une méthode restore(...). Écris les tests unitaires du domaine, sans Spring ni Mockito, et lance-les.
   ```
   ✔ À vérifier : aucun import Spring/JPA, pas de setter, tests verts.
2. Application :
   ```
   Dans catalog/application, crée le port d'entrée RegisterBookUseCase avec RegisterBookCommand, les ports de sortie
   nécessaires (unicité de l'ISBN, sauvegarde) et le use case RegisterBookService annoté @UseCase.
   Teste-le avec un fake en mémoire des ports de sortie.
   ```
   ✔ À vérifier : le use case ne contient pas de logique de validation de l'ISBN (elle est dans `Isbn`).
   Les ports s'appellent d'après le besoin (`ExistsBookByIsbnPort`, `SaveBookPort`), pas `BookJpaPort`.
3. Persistance :
   ```
   Dans catalog/adapter/out/persistence, crée la migration Flyway, BookJpaEntity, le repository Spring Data, le mapper
   et BookPersistenceAdapter qui implémente les ports de sortie. Teste l'adapter avec @DataJpaTest et Testcontainers.
   ```
   ✔ À vérifier : `BookJpaEntity` et `Book` sont deux classes différentes ; contrainte unique sur l'ISBN en base.
4. Web :
   ```
   Dans catalog/adapter/in/web, crée POST /api/v1/books réservé au rôle LIBRARIAN, les DTO, et le gestionnaire
   d'exceptions qui renvoie un ProblemDetail (409 si ISBN déjà connu, 422 si ISBN invalide). Teste avec @WebMvcTest.
   ```
   ✔ À vérifier : le contrôleur injecte `RegisterBookUseCase` (l'interface), pas `RegisterBookService`.
5. Lance `./mvnw test`. Tout doit être vert, `ArchitectureTest` compris.

Checklist :
- [ ] Dessine dans le journal le schéma des dépendances entre tes classes : toutes les flèches pointent vers le domaine.
- [ ] Le test de domaine de l'ISBN s'exécute en moins d'une seconde.

Pièges :
- Claude peut proposer de « simplifier » en mettant `@Entity` sur `Book`. Refuse : c'est exactement ce que l'architecture interdit.
- Un use case qui renvoie `BookJpaEntity` ou un DTO web : il doit renvoyer un type du domaine ou un objet résultat de l'application.

### Exercice 2.3 — Casser l'architecture volontairement
**Objectif** : voir les garde-fous fonctionner, et savoir lequel attrape quoi.

Étapes :
1. Demande :
   ```
   Pour aller plus vite, ajoute l'annotation @Entity directement sur la classe Book du domaine.
   ```
   Observe : le hook `guard-architecture.sh` bloque (règle `domain` du `rules.conf`) et renvoie le message à Claude. Note la réaction de Claude.
2. Demande :
   ```
   Dans le contrôleur des livres, injecte directement BookJpaRepository pour vérifier que l'ISBN n'existe pas déjà.
   ```
   Le hook bloque aussi ce cas (règle `adapter/in`).
3. Le hook ne lit que les lignes `import`. Demande :
   ```
   Dans le contrôleur des livres, utilise BookJpaRepository en écrivant son nom complet (com.example...BookJpaRepository), sans import.
   ```
   Ce cas passe le hook. Lance `./mvnw test -Dtest=ArchitectureTest` : la règle `inbound_adapters_use_input_ports_only` doit échouer.
4. Annule les changements (`git checkout .`).

Checklist :
- [ ] Le journal contient un tableau « violation → garde-fou qui l'attrape (hook / ArchUnit / revue) ».
- [ ] Tu as compris pourquoi on garde les deux : le hook réagit immédiatement, ArchUnit couvre tout le code.

### Variante couche (si `factory.json` vaut `"couche"`)
Même démarche, avec les couches de la référence `couche` :

| Exercice | Adaptation |
|---|---|
| 2.1 | `/init-architecture catalog` crée `catalog/{controller,dto,service,mapper,repository,entity,exception}` et l'`ArchitectureTest` « couche » (`layeredArchitecture()`). |
| 2.2 | Prompts dans l'ordre : migration → entité `Book` → `BookRepository` → DTO + `BookMapper` → `BookService` (unicité de l'ISBN, tests Mockito) → `BookController` (`POST /api/v1/books`, `@WebMvcTest`). À vérifier : le contrôleur ne reçoit et ne renvoie que des DTO ; la règle RM-07 est dans le service. |
| 2.3 | Casse 1 : `Injecte BookRepository directement dans BookController` → bloqué par le hook (règle `controller`). Casse 2 : `Fais renvoyer une ResponseEntity par BookService` → bloqué (règle `service`). Casse 3 : nom complet sans import → seul ArchUnit l'attrape. |

---

## Niveau 3 — Commandes personnalisées (1 jour)

**Concept** : un prompt qui marche se capitalise dans `.claude/commands/<nom>.md`, appelé par `/<nom>`.
`$ARGUMENTS` reçoit ce que tu tapes après la commande.

### Exercice 3.1 — Lire les commandes du kit
Lis `feature.md`, `fix-bug.md`, `review-mr.md`, `init-architecture.md`. Pour chacune, note dans le journal :
son déclencheur, ses étapes, ses points d'arrêt (où elle attend ta validation).

### Exercice 3.2 — Écrire `/add-usecase`
**Objectif** : écrire ta première commande, qui reproduit automatiquement la démarche de l'exercice 2.2.

Cahier des charges de la commande :
- Appel : `/add-usecase <context> <NomDuUseCase> <description et règles RM-xx>`.
- Elle charge les skills `architecture` et `spring-boot-conventions`, et lit la référence active.
- Elle **commence par afficher un plan** (classes à créer par couche) et attend ta validation.
- Puis elle code dans l'ordre d'implémentation de la référence active, avec les tests de chaque couche.
- Elle termine en lançant `./mvnw test` et en affichant un résumé par couche.

Étapes :
1. Crée `.claude/commands/add-usecase.md` (inspire-toi de `feature.md` pour le format : en-tête `description`, `argument-hint`, puis les étapes).
2. Teste-la :
   ```
   /add-usecase loan ReturnBook Rendre un livre emprunté (RM-05) : l'emprunt est clôturé à la date du jour, l'exemplaire redevient disponible.
   ```
3. Si une étape est sautée ou mal faite, corrige le fichier de la commande (pas le code), annule le code (`git checkout . && git clean -fd`) et relance.
   Itère jusqu'à obtenir un résultat correct du premier coup.

Résultat attendu : `ReturnBookUseCase`, `Loan.giveBack(...)` qui refuse un double retour, tests de domaine et de use case, endpoint `POST /api/v1/loans/{id}/return`.

Checklist :
- [ ] La commande s'arrête bien après le plan.
- [ ] Le résultat passe `ArchitectureTest` sans correction manuelle.
- [ ] Tu as noté combien d'itérations sur le fichier de commande ont été nécessaires, et pourquoi.

Piège : une commande trop vague (« implémente le use case proprement ») donne des résultats variables. Sois aussi explicite que dans l'exercice 2.2.

---

## Niveau 4 — Skills (1 à 2 jours)

**Concept** : un skill est un savoir-faire chargé **seulement quand la tâche le justifie**, grâce à sa `description`.
`CLAUDE.md` reste court ; le détail vit dans les skills.

### Exercice 4.1 — Observer le chargement des skills
1. Relis `architecture/SKILL.md` : c'est un aiguilleur, il renvoie vers la référence active (`factory.json`).
2. Demande, **sans nommer de skill** :
   ```
   Explique-moi où doit se trouver la règle RM-01 et pourquoi.
   ```
   Observe si Claude charge le skill `architecture` (il l'annonce dans sa réponse), puis s'il lit la bonne référence.
3. Demande ensuite : `Quelle est la capitale du Sénégal ?` → aucun skill ne doit être chargé.

Checklist :
- [ ] Tu sais expliquer le rôle du champ `description` dans le déclenchement.

### Exercice 4.2 — Écrire le skill `flyway-migrations`
**Objectif** : formaliser tes propres règles de migration.

Contenu attendu du skill (`.claude/skills/flyway-migrations/SKILL.md`) :
- nommage des fichiers et des contraintes ;
- types PostgreSQL à utiliser (`uuid`, `timestamptz`, `numeric(…)`, `text` vs `varchar`) ;
- règles d'index ;
- comment ajouter une colonne `NOT NULL` à une table qui a déjà des données (en 2 ou 3 migrations) ;
- comment renommer une colonne sans casser une version en production ;
- un exemple complet de migration.

Test :
```
Ajoute aux livres une colonne obligatoire « langue » (code ISO à 2 lettres), sachant que la table contient déjà des données.
```
Claude doit charger ton skill sans que tu le nommes, et produire plusieurs migrations (ajout nullable → remplissage → contrainte NOT NULL).

Checklist :
- [ ] Le skill est chargé automatiquement.
- [ ] Les migrations produites suivent tes règles.

### Exercice 4.3 — Écrire le skill métier `library-domain`
**Objectif** : donner à Claude le **langage du métier** (ubiquitous language), pilier de la clean architecture.

Contenu : glossaire (membre, exemplaire, emprunt actif, retard, prolongation), règles RM-01 à RM-07,
correspondance français ↔ noms de classes anglais (`emprunt` → `Loan`, `exemplaire` → `Copy`…).

Test :
```
Quand un membre a-t-il le droit de prolonger un emprunt ?
```
Claude doit répondre avec RM-06 et les bons termes.

Checklist :
- [ ] Les noms de classes générés ensuite respectent ton glossaire.

### Exercice 4.4 — Ajouter une architecture : `clean`
**Objectif** : étendre la factory sans toucher aux agents, en respectant le contrat des références.

Étapes :
1. Dans le dépôt du kit (pas dans Bibliothèque) : `cp -r .claude/skills/architecture/references/_template .claude/skills/architecture/references/clean`.
2. Écris `clean/REFERENCE.md` avec les 9 sections. Distingue-la vraiment de `hexagonal` :
   les quatre cercles `entities` → `usecases` → `interfaceadapters` → `frameworks`, la règle de dépendance vers le centre,
   les « presenters » et les « gateways ».
3. Écris `ArchitectureTest.java` (première ligne `// architecture: clean`), `rules.conf` et `scaffold.md`.
4. Lance `bash tools/check-references.sh` jusqu'à ce qu'il soit vert.
5. Sur un **nouveau** petit projet, mets `"architecture": "clean"` dans `factory.json`, lance `/init-architecture`, puis une petite `/feature`.

Checklist :
- [ ] Aucun fichier d'agent n'a été modifié.
- [ ] Le `backend-dev` annonce « Architecture appliquée : clean » et respecte ton ordre d'implémentation.

---

## Niveau 5 — Sous-agents et orchestration (2 à 3 jours)

**Concept** : un sous-agent travaille dans son propre contexte, avec ses outils et son modèle.
Sa `description` décide quand l'agent principal lui délègue le travail.

### Exercice 5.1 — Dérouler `/feature` et suivre chaque agent
1. Lance :
   ```
   /feature Emprunter un livre : un membre emprunte un exemplaire disponible, en respectant RM-01 à RM-04.
   ```
2. À chaque étape, note dans le journal : quel agent travaille, ce qu'il reçoit, ce qu'il rend.
3. Quand `spec-writer` a fini : ouvre `docs/specs/`, relis la spec, corrige-la si besoin **avant** de valider.
4. Quand `architect` présente le plan : vérifie la section « Domaine ». RM-01 et RM-02 doivent être dans le domaine (`LoanPolicy` ou équivalent), pas dans le use case. Refuse le plan si ce n'est pas le cas, en expliquant pourquoi.
5. Laisse la suite se dérouler jusqu'au verdict du `reviewer`.

Checklist :
- [ ] Le journal contient la chaîne complète des 6 agents.
- [ ] Tu as refusé ou corrigé au moins une étape (spec ou plan), et noté pourquoi.
- [ ] `./mvnw test` est vert à la fin.

### Exercice 5.2 — Piéger le reviewer
1. Sur une nouvelle branche, introduis **toi-même** trois défauts :
   - une règle métier dans un contrôleur (`if (activeLoans >= 3)`) ;
   - un endpoint sans `@PreAuthorize` ;
   - une boucle qui appelle un repository à chaque itération (N+1).
2. Commit, puis `/review-mr main`.
3. Compare ce que le reviewer a trouvé avec ta liste.

Checklist :
- [ ] Les 3 défauts sont détectés, avec la bonne sévérité. Sinon, améliore `reviewer.md` et recommence.

### Exercice 5.3 — Créer l'agent `security-auditor`
Cahier des charges (`.claude/agents/security-auditor.md`) :
- lecture seule (`Read, Glob, Grep`) ;
- vérifie : autorisations par rôle, IDOR (identité prise du JWT), validation des entrées, injections SQL dans les requêtes natives,
  données personnelles dans les logs, secrets, configuration CORS ;
- même format de rapport que `reviewer`.

Puis ajoute dans `feature.md` une étape qui l'appelle après le `reviewer`.
Test : relance l'exercice 5.2 et vérifie qu'il trouve l'endpoint non protégé.

### Exercice 5.4 — Comparer les modèles
1. Mets `model: haiku` dans `reviewer.md`, relance `/review-mr` sur la branche de l'exercice 5.2. Note le temps et les défauts trouvés.
2. Même chose avec `sonnet`, puis `opus`.
3. Conclus dans le journal : quel modèle pour quel agent, et pourquoi.

---

## Niveau 6 — Hooks : les garanties (1 à 2 jours)

**Concept** : un prompt *suggère*, un hook *garantit*. Un hook est un script lancé par Claude Code à un moment précis ;
il reçoit le contexte en JSON sur l'entrée standard, et un code de sortie `2` bloque l'action en renvoyant le message d'erreur à Claude.

### Exercice 6.1 — Lire et tester les hooks du kit
1. Lis `settings.json` et les 5 scripts de `.claude/hooks/` (`session-start`, `guard-bash`, `guard-files`, `guard-architecture`, `post-edit-check`).
2. Dans `claude`, tape `/hooks` : les hooks doivent apparaître.
3. Teste les scripts **sans Claude**, directement dans le terminal :
   ```bash
   echo '{"tool_input":{"command":"git push origin main"}}' | .claude/hooks/guard-bash.sh; echo "code=$?"
   echo '{"tool_input":{"command":"git push origin feature/x"}}' | .claude/hooks/guard-bash.sh; echo "code=$?"
   ```
   Attendu : `code=2` puis `code=0`.

Checklist :
- [ ] Pour chaque hook, tu sais dire : quel événement, quel outil, ce qu'il bloque.

### Exercice 6.2 — Hook de format de commit
**Objectif** : refuser tout commit qui ne respecte pas Conventional Commits.

Cahier des charges :
- nouveau script `.claude/hooks/guard-commit.sh`, déclaré en `PreToolUse` avec le matcher `Bash` ;
- s'il s'agit d'un `git commit -m "..."`, le message doit respecter :
  `^(feat|fix|refactor|test|docs|chore)(\([a-z-]+\))?: .+`
- sinon : `exit 2` avec un message qui explique le format attendu et donne un exemple.

Tests :
1. Dans le terminal, avec un JSON simulé (comme en 6.1), un message valide et un message invalide.
2. Dans `claude` : `Commite les changements avec le message "maj"`. Claude doit être bloqué, puis proposer un message conforme.

### Exercice 6.3 — Hook `Stop` : ne jamais finir avec des tests rouges
**Objectif** : empêcher Claude de déclarer une tâche terminée si les tests échouent.

Cahier des charges :
- script `.claude/hooks/tests-must-pass.sh`, déclaré sur l'événement `Stop` (sans matcher) ;
- il lance `cd backend && ./mvnw -q test` ;
- si les tests échouent : `exit 2` avec les 20 premières lignes d'erreur (Claude reprend alors le travail) ;
- **important** : lis le champ `stop_hook_active` du JSON reçu. S'il vaut `true`, sors avec `exit 0`,
  sinon tu risques une boucle infinie.

Test : casse volontairement un test de domaine, demande à Claude une petite modification sans rapport, et observe qu'il ne peut pas s'arrêter avant d'avoir réparé le test.

Checklist :
- [ ] Le hook ne boucle pas indéfiniment.
- [ ] Tu as mesuré le temps ajouté à chaque fin de tâche, et décidé si c'est acceptable (sinon : lancer seulement les tests du domaine).

### Exercice 6.4 — Synthèse
Remplis ce tableau dans le journal pour **toutes** les règles de ton `CLAUDE.md` :

| Règle | CLAUDE.md | Skill | Hook | ArchUnit / test | Revue |
|---|---|---|---|---|---|
| Domaine sans framework | rappel | détail | blocage immédiat | garantie globale | contrôle |
| … | | | | | |

✅ Fin du niveau quand tu sais justifier, pour chaque règle, où elle doit vivre.

---

## Projet final — une fonctionnalité de bout en bout
Implémente **RM-06 (prolongation d'emprunt)**, backend et écran Angular, uniquement avec ta factory :
```
/feature Prolonger un emprunt : un membre peut prolonger une seule fois de 7 jours un emprunt non en retard (RM-06). Bouton « Prolonger » dans la liste de ses emprunts.
```
Mesure et note : temps total, nombre de fois où tu as dû intervenir, défauts trouvés par la revue, verdict final.
Puis améliore les agents, skills ou hooks responsables de tes interventions, et recommence sur une branche propre.
La factory est prête quand elle livre cette fonctionnalité avec au plus une intervention de ta part, hors validations prévues.

---

## Rendre la factory portable
- Agents et skills génériques (architecture, revue, tests) → `~/.claude/agents/` et `~/.claude/skills/` : disponibles dans tous tes projets.
- Spécifique à un projet (skill métier, CLAUDE.md, commandes du projet) → `.claude/` du dépôt.
- Versionne le kit dans son propre dépôt Git, avec un changelog : fais-le évoluer comme un produit.

## Annexe (optionnelle, plus tard) — Intégration continue
Quand les 6 niveaux sont maîtrisés, tu pourras faire tourner la factory dans un pipeline : revue automatique des MR,
implémentation déclenchée depuis GitLab. Les fichiers d'exemple sont dans `extras/ci/` (GitLab et Jenkins).
Ils ne sont nécessaires à aucun exercice de ce parcours.

## Ressources
- Documentation Claude Code : https://code.claude.com/docs
- Les fonctionnalités évoluent vite : en cas de doute sur un champ ou une option, `claude --help` et la documentation font foi.
