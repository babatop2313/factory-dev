# Cap suivant — conventions, intégrations, multi-IA et plugin

> Document de cadrage : ce qui est prévu après la v3.3, et pourquoi. Chaque étape sera validée sur Bibliothèque,
> comme les précédentes.

## v3.4 — Conventions et intégrations ✅ (livrée)
> Prochaine étape : valider `redis` sur Bibliothèque (`/add-integration redis`, puis un cache sur `list_available_books`)
> et passer sa référence à « testée ».
**Le constat** : le skill `spring-boot-conventions` mélange deux axes qui ne vivent pas au même rythme.

| Axe | Exemple | Choisi | Change en cours de projet ? |
|---|---|---|---|
| **Conventions** : comment on code | mapping, Lombok, format des erreurs, stratégie d'id | au démarrage | rarement |
| **Intégrations** : avec quoi on se connecte | PostgreSQL, Redis, Kafka, mail, stockage objet… | à tout moment | **oui, on en ajoute** |

Contrairement à l'architecture, une intégration s'ajoute au troisième sprint : elle ne va donc pas dans `factory.json`
(verrouillé), mais dans un fichier modifiable **`.claude/stack.json`** :
```json
{
  "profile": "top",
  "integrations": ["postgresql", "redis"],
  "conventions": { "mapping": "mapstruct", "lombok": true, "errors": "problem-detail", "ids": "uuid" }
}
```

**Structure prévue**
```
.claude/skills/
  conventions/
    SKILL.md                     aiguilleur
    references/
      socle/REFERENCE.md         toujours appliqué, non négociable
      profiles/top/              profil personnel « TOP » : préférences communes à mes projets
      options/                   une fiche par option (mapping.md, lombok.md, errors.md, ids.md…)
  integrations/
    SKILL.md                     aiguilleur : lit stack.json, ne lit QUE la référence de la techno touchée
    references/
      _template/
      postgresql/  redis/  mail/  …   REFERENCE.md, scaffold.md, rules.conf
```
**Priorités en cas de conflit** : architecture > socle > options du projet > profil (le profil ne fournit que des valeurs
par défaut) ; le `CLAUDE.md` du projet précise, sans contredire.
Un projet choisit ses options, mais ne déroge jamais au socle (injection par constructeur, aucun secret, Flyway,
pas d'IDOR, aucune donnée personnelle dans les logs). Les options démarrent peu nombreuses, avec pour valeurs par défaut
les conventions actuelles : on en ajoutera quand un vrai besoin apparaîtra.

**Contrat d'une référence d'intégration** (vérifié par `check-references.sh`) : Résumé · Cas d'usage (et contre-indications) ·
Dépendances · Connexion et configuration (variables d'environnement, timeouts, TLS) · Rôle dans l'architecture ·
Conventions (nommage des clés, des topics…) · Résilience (comportement si le service tombe) · Sécurité · Observabilité ·
Développement local · Tests (module Testcontainers) · Grille de revue. Plus un **statut** : `testée` ou `non testée`.

**Des rôles pour éviter N × M** : chaque référence d'architecture déclare une fois où va chaque rôle technique
(adapter entrant HTTP, messagerie, MCP ; adapter sortant persistance, cache, messagerie, fichiers, mail). Une intégration
ne dit que « je suis un adapter sortant de cache ». Ajouter une techno = écrire **une** référence, valable pour toutes
les architectures. Chaque intégration fournit aussi son `rules.conf` (ex. `org.springframework.data.redis` importé
seulement dans le rôle cache), appliqué par le moteur du hook d'architecture.

**Contexte de Claude préservé** : `session-start` n'injecte qu'une ligne par intégration active ; la référence complète
n'est lue que lorsqu'on touche à la techno.

**Commande `/add-integration <techno>`** : dépendance, configuration par variables d'environnement, module Testcontainers,
health check, mise à jour de `stack.json`. Le code métier passe ensuite par `/feature`.

**Ordre d'écriture** (des plus simples aux plus complexes ; toutes écrites, testées au fil de l'eau) :

| Techno | Rôle | Statut prévu en v3.4 | Validation sur Bibliothèque |
|---|---|---|---|
| postgresql | adapter sortant persistance | testée (déjà utilisée) | — |
| redis | adapter sortant cache | testée | cache sur `list_available_books`, invalidé à l'enregistrement |
| mail (SMTP) | adapter sortant notification | non testée | (plus tard) rappel de retour d'emprunt |
| stockage objet (S3 / MinIO) | adapter sortant fichiers | non testée | (plus tard) couverture d'un livre |
| rabbitmq | adapter entrant/sortant messagerie | non testée | — |
| kafka | adapter entrant/sortant messagerie | non testée | (plus tard) `catalog.book.registered.v1` consommé par `loan` |

## v4.0 — Noyau neutre (préparer le multi-IA)
Appliquer l'architecture hexagonale à la factory elle-même : un **noyau neutre** et des **adaptateurs par outil**.
```
core/          factory.json, stack.json, références (architecture, conventions, intégrations),
               règles → AGENTS.md, skills au format SKILL.md, workflow docs/specs
adapters/
  claude/      agents, commandes, hooks, settings.json, .mcp.json
  copilot/     instructions, prompts, configuration MCP
  gemini/      extension : contexte, commandes, configuration MCP
```
- **Les garanties ne doivent plus dépendre des hooks d'un outil** : ArchUnit (déjà en place), un **hook Git `pre-commit`**
  qui réutilise le moteur `rules.conf`, et la CI. Les hooks de Claude deviennent un confort (retour immédiat), pas la
  seule protection. Une factory multi-IA est sûre si elle reste sûre avec une IA indisciplinée.
- `tools/build-adapters.sh` génère les fichiers de chaque outil à partir du noyau : une seule source de vérité.

| Élément | Portabilité entre outils |
|---|---|
| Skills (SKILL.md) | très bonne : standard ouvert repris par la plupart des outils |
| Règles | bonne : `AGENTS.md` (Gemini lit `GEMINI.md` par défaut, configurable) |
| Serveurs MCP | bonne : seul le fichier de configuration change |
| Commandes | moyenne : un format par outil, d'où le générateur |
| Sous-agents | moyenne : notions très différentes |
| Hooks | faible : remplacés par le hook Git et la CI pour ce qui est obligatoire |

## v4.1 — `factory-mcp`, la factory comme serveur MCP
Serveur en **Java / Spring AI, transport stdio**, utilisable par tous les clients : `get_architecture`,
`get_reference_section`, `check_architecture(fichier)` (applique les `rules.conf`), `list_integrations`, `list_specs`…
Dans Claude Code, il ferait doublon avec les skills ; il prend tout son sens pour Copilot et Gemini.

## v4.2 — Plugin Claude Code
La factory s'installe en une commande depuis un marketplace (le dépôt GitHub du kit) : agents, skills, hooks, commandes
et serveurs MCP regroupés. Fin des copies de `.claude/`.

## v4.3 et v4.4 — Copilot, puis Gemini CLI
Un adaptateur par outil, généré depuis le noyau, **validé sur Bibliothèque** avec les mêmes scénarios que pour Claude.
Objectif réaliste : les mêmes règles et les mêmes garde-fous partout, pas une expérience identique dans chaque outil.
