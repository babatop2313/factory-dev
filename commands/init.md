---
description: Initialise (ou met à jour) la Top Factory dans le projet courant — détection du backend et du frontend, choix de l'architecture, de la branche d'intégration et des intégrations, puis fichiers du projet. Mode plugin uniquement.
argument-hint: [architecture, ex. hexagonal]
---

Architecture souhaitée (facultatif) : $ARGUMENTS

Tu prépares le projet courant pour la Top Factory. **Toute l'écriture est faite par le script du kit** (`install.sh`) :
tu ne crées et ne modifies jamais toi-même `.claude/factory.json`, `.claude/stack.json` ni `.claude/settings.json`,
et tu ne touches jamais à `.claude/settings.local.json`. Si le script échoue, rapporte son message : ne le contourne pas.

1. **Kit** : `<kit>` est annoncé au début de la session (« <kit> = … »). S'il ne l'est pas, arrête-toi : le plugin
   n'est pas chargé ; demande-moi de lancer `/plugin install top-factory@top` puis de relancer Claude.

2. **Détection** (aucune écriture), depuis la racine du projet :
   `bash "<kit>/tools/install.sh" . --detect`
   Lis le résultat :
   - `git : non` → propose-moi `git init` et attends mon accord avant de le lancer.
   - `factory.json` présent → **mise à jour** : l'architecture est verrouillée, ne pose aucune question à son sujet.
     Lance `bash "<kit>/tools/install.sh" . --mode plugin`, puis va à l'étape 6.
   - `backend :` vide → aucun `pom.xml` Spring Boot trouvé. Arrête-toi et explique-moi comment générer le backend
     (start.spring.io : Maven, Java 21, dépendances Web, Validation, Data JPA, PostgreSQL Driver, Flyway, Security,
     Actuator, Testcontainers), dans le dossier de mon choix, puis de relancer `/top-factory:init`.
     Ne continue sans backend que si je le demande explicitement.
   - plusieurs dossiers backend ou frontend → je choisirai à l'étape 3.

3. **Questions** : pose-les **en une seule fois** (outil de questions à choix s'il est disponible) :
   - **Architecture** : celles listées par `--detect`. Pour chacune, une ligne tirée de la section « Résumé » de
     `<kit>/skills/architecture/references/<nom>/REFERENCE.md`. Si `$ARGUMENTS` en désigne une, propose-la en premier.
     Rappelle qu'elle sera **verrouillée** : elle ne changera plus en cours de projet.
   - **Branche d'intégration** : `develop` par défaut ; regarde `git branch -a` et signale si elle n'existe pas encore.
   - **Intégrations** (choix multiple) : celles listées par `--detect`, avec leur statut (ligne `> Statut :` de chaque
     `REFERENCE.md`) ; `postgresql` par défaut. Les autres pourront s'ajouter plus tard avec `/top-factory:add-integration`.
   - **Dossiers** : le backend et le frontend détectés, à confirmer (ou à choisir s'il y en a plusieurs). Sans frontend
     détecté, propose `frontend` (dossier à créer plus tard) ; un projet sans Angular est permis.

4. **Récapitulatif** : architecture, branche, intégrations, dossiers, et la commande exacte que tu vas lancer.
   **Attends mon accord explicite** : c'est la seule étape qui fixe l'architecture.

5. **Installation** :
   `bash "<kit>/tools/install.sh" . --architecture <a> --base-branch <b> --backend <dossier> --frontend <dossier> --integrations <i1,i2> --mode plugin`

6. **Clôture** : donne-moi
   - les fichiers créés ou modifiés (sortie du script) et ce que contient `.claude/factory.json` (lu avec Read) ;
   - **la suite, dans l'ordre** :
     1. relancer Claude (`/exit`, puis `claude` à la racine du projet) : les permissions et les hooks du projet ne se
        chargent qu'au démarrage ; le message de début de session doit annoncer `TOP FACTORY`, l'architecture et les dossiers ;
     2. compléter `CLAUDE.md` (contexte métier, règles, commandes) — propose de m'aider après le redémarrage ;
     3. `/top-factory:init-architecture <premier-module>` (ex. `catalog`) ;
     4. commiter l'initialisation dans une branche (ex. `chore/top-factory-init`).

Ne commite rien, ne pousse rien et ne lance pas `/top-factory:init-architecture` toi-même : ces étapes attendent mon accord
et le redémarrage de Claude.
